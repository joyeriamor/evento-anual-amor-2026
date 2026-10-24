import { serveEvento } from "../_shared/evento.ts";

import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const SUPABASE_URL =
  Deno.env.get("SUPABASE_URL") ?? "";

const SUPABASE_ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  "";

const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const ORIGENES_PERMITIDOS = [
  "https://joyeriamor.github.io",
  "http://localhost:5173",
];

const MAX_POR_PAGINA = 50;

function responder(
  datos: Record<string, unknown>,
  status: number,
  origen: string
) {
  return new Response(JSON.stringify(datos), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": origen,
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      Vary: "Origin",
    },
  });
}

serveEvento({ roles: ['administrador'] }, async (req) => {
  const origen = req.headers.get("origin") ?? "";

  if (
    origen &&
    !ORIGENES_PERMITIDOS.includes(origen)
  ) {
    return new Response("Origen no permitido", {
      status: 403,
    });
  }

  const corsOrigin =
    origen || "http://localhost:5173";

  if (req.method === "OPTIONS") {
    return responder({}, 200, corsOrigin);
  }

  if (req.method !== "POST") {
    return responder(
      {
        ok: false,
        mensaje: "Método no permitido",
      },
      405,
      corsOrigin
    );
  }

  if (
    !SUPABASE_URL ||
    !SUPABASE_ANON_KEY ||
    !SUPABASE_SERVICE_ROLE_KEY
  ) {
    return responder(
      {
        ok: false,
        mensaje: "Configuración incompleta",
      },
      503,
      corsOrigin
    );
  }

  const authorization =
    req.headers.get("authorization") ?? "";

  if (!authorization.startsWith("Bearer ")) {
    return responder(
      {
        ok: false,
        mensaje: "Sesión requerida",
      },
      401,
      corsOrigin
    );
  }

  const token = authorization.slice(7).trim();

  if (!token) {
    return responder(
      {
        ok: false,
        mensaje: "Token inválido",
      },
      401,
      corsOrigin
    );
  }

  try {
    // Verificar el token directamente
    // con Supabase Auth.
    const authClient = createClient(
      SUPABASE_URL,
      SUPABASE_ANON_KEY,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await authClient.auth.getUser(token);

    if (authError || !user) {
      return responder(
        {
          ok: false,
          mensaje: "Sesión inválida",
        },
        401,
        corsOrigin
      );
    }

    // Este cliente privilegiado existe
    // exclusivamente dentro de la función.
    const adminClient = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      }
    );

    // Comprobar permisos en CADA solicitud.
    const {
      data: usuario,
      error: usuarioError,
    } = await adminClient
      .from("usuarios")
      .select("id, rol, activo")
      .eq("id", user.id)
      .maybeSingle();

    if (usuarioError) {
      console.error(
        "Error verificando permisos:",
        usuarioError.message
      );

      return responder(
        {
          ok: false,
          mensaje: "Error al verificar permisos",
        },
        500,
        corsOrigin
      );
    }

    if (
      !usuario ||
      usuario.activo !== true ||
      usuario.rol !== "administrador"
    ) {
      return responder(
        {
          ok: false,
          mensaje: "Acceso no autorizado",
        },
        403,
        corsOrigin
      );
    }

    // Leer filtros y paginación.
    let entrada: unknown;

    try {
      entrada = await req.json();
    } catch {
      return responder(
        {
          ok: false,
          mensaje: "JSON inválido",
        },
        400,
        corsOrigin
      );
    }

    if (
      !entrada ||
      typeof entrada !== "object" ||
      Array.isArray(entrada)
    ) {
      return responder(
        {
          ok: false,
          mensaje: "Solicitud inválida",
        },
        400,
        corsOrigin
      );
    }

    const parametros = entrada as Record<
      string,
      unknown
    >;

    const paginaSolicitada =
      parametros.pagina ?? 1;

    const limiteSolicitado =
      parametros.limite ?? 20;

    if (
      !Number.isSafeInteger(paginaSolicitada) ||
      Number(paginaSolicitada) < 1 ||
      Number(paginaSolicitada) > 100000 ||
      !Number.isSafeInteger(limiteSolicitado) ||
      Number(limiteSolicitado) < 1 ||
      Number(limiteSolicitado) > MAX_POR_PAGINA
    ) {
      return responder(
        {
          ok: false,
          mensaje: "Paginación inválida",
        },
        400,
        corsOrigin
      );
    }

    const pagina = Number(paginaSolicitada);
    const limite = Number(limiteSolicitado);

    const busqueda =
      typeof parametros.busqueda === "string"
        ? parametros.busqueda.trim()
        : "";

    if (busqueda.length > 100) {
      return responder(
        {
          ok: false,
          mensaje: "Búsqueda demasiado larga",
        },
        400,
        corsOrigin
      );
    }

    // Filtro opcional de evento.
    const eventoId = req.headers.get('x-evento-autorizado')!;

    if (
      eventoId !== undefined &&
      (
        typeof eventoId !== "string" ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
          .test(eventoId)
      )
    ) {
      return responder(
        {
          ok: false,
          mensaje: "Evento inválido",
        },
        400,
        corsOrigin
      );
    }

    const inicio = (pagina - 1) * limite;
    const fin = inicio + limite - 1;

    // Consulta privada con relaciones.
    // No incluimos rutas de archivos.
    let consulta = adminClient
      .from("registros")
      .select(
        `
        id,
        folio,
        estado,
        exento_pago,
        created_at,
        evento_id,
        promotora:promotoras!registros_promotora_id_fkey (
          nombres,
          apellidos,
          telefono_whatsapp,
          estado_residencia
        ),
        asesor:asesores!registros_asesor_id_fkey (
          nombre
        ),
        evento:eventos!registros_evento_id_fkey (
          nombre,
          cuota_fija
        ),
        pago:pagos (
          importe,
          estado,
          cuenta_destino
        )
        `,
        { count: "exact" }
      )
      .order("created_at", {
        ascending: false,
      });

    if (typeof eventoId === "string") {
      consulta = consulta.eq(
        "evento_id",
        eventoId
      );
    }

    // La búsqueda se realiza por nombre,
    // apellido o WhatsApp sobre promotoras.
    // Primero identificamos los IDs que
    // coinciden y luego filtramos registros.
    if (busqueda) {
      const textoSeguro = busqueda
        .replace(/[,%()]/g, " ")
        .trim();

      if (!textoSeguro) {
        return responder(
          {
            ok: false,
            mensaje: "Búsqueda inválida",
          },
          400,
          corsOrigin
        );
      }

      const {
        data: coincidencias,
        error: busquedaError,
      } = await adminClient
        .from("promotoras")
        .select("id")
        .or(
          [
            `nombres.ilike.%${textoSeguro}%`,
            `apellidos.ilike.%${textoSeguro}%`,
            `telefono_whatsapp.ilike.%${textoSeguro}%`,
          ].join(",")
        )
        .limit(500);

      if (busquedaError) {
        console.error(
          "Error buscando participantes:",
          busquedaError.message
        );

        return responder(
          {
            ok: false,
            mensaje: "No se pudo realizar la búsqueda",
          },
          500,
          corsOrigin
        );
      }

      const ids = (coincidencias ?? []).map(
        (item) => item.id
      );

      if (ids.length === 0) {
        return responder(
          {
            ok: true,
            pagina,
            limite,
            total: 0,
            participantes: [],
          },
          200,
          corsOrigin
        );
      }

      consulta = consulta.in(
        "promotora_id",
        ids
      );
    }

    const {
      data: registros,
      error: registrosError,
      count,
    } = await consulta.range(inicio, fin);

    if (registrosError) {
      console.error(
        "Error consultando registros:",
        registrosError.message
      );

      return responder(
        {
          ok: false,
          mensaje: "No se pudieron consultar las inscripciones",
        },
        500,
        corsOrigin
      );
    }

    return responder(
      {
        ok: true,
        pagina,
        limite,
        total: count ?? 0,
        participantes: registros ?? [],
      },
      200,
      corsOrigin
    );
  } catch (error) {
    console.error(
      "Error interno en listar-participantes:",
      error
    );

    return responder(
      {
        ok: false,
        mensaje: "Error interno del servidor",
      },
      500,
      corsOrigin
    );
  }
});
