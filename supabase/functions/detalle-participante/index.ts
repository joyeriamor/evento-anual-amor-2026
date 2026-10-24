import { serveEvento } from "../_shared/evento.ts";

import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const URL = Deno.env.get("SUPABASE_URL") ?? "";

const PUBLIC_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  "";

const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const ORIGENES = ["http://localhost:5173", "https://joyeriamor.github.io"];

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function respuesta(
  cuerpo: Record<string, unknown>,
  estado: number,
  origen: string
) {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": origen,
      "Access-Control-Allow-Headers":
        "authorization, apikey, content-type, x-client-info",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      Vary: "Origin",
    },
  });
}

serveEvento({ roles: ['administrador'] }, async (req) => {
  const origen = req.headers.get("origin") ?? "";

  if (origen && !ORIGENES.includes(origen)) {
    return new Response("Origen no permitido", {
      status: 403,
    });
  }

  const cors = origen || ORIGENES[0];

  if (req.method === "OPTIONS") {
    return respuesta({}, 200, cors);
  }

  if (req.method !== "POST") {
    return respuesta(
      { ok: false, mensaje: "Método no permitido" },
      405,
      cors
    );
  }

  if (!URL || !PUBLIC_KEY || !SERVICE_KEY) {
    return respuesta(
      { ok: false, mensaje: "Configuración incompleta" },
      503,
      cors
    );
  }

  const autorizacion =
    req.headers.get("authorization") ?? "";

  if (!autorizacion.startsWith("Bearer ")) {
    return respuesta(
      { ok: false, mensaje: "Sesión requerida" },
      401,
      cors
    );
  }

  try {
    const token = autorizacion.slice(7).trim();

    const auth = createClient(URL, PUBLIC_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: authData, error: authError } =
      await auth.auth.getUser(token);

    if (authError || !authData.user) {
      return respuesta(
        { ok: false, mensaje: "Sesión inválida" },
        401,
        cors
      );
    }

    const admin = createClient(URL, SERVICE_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: usuario, error: errorUsuario } =
      await admin
        .from("usuarios")
        .select("rol, activo")
        .eq("id", authData.user.id)
        .maybeSingle();

    if (errorUsuario) {
      console.error(errorUsuario.message);

      return respuesta(
        { ok: false, mensaje: "Error verificando permisos" },
        500,
        cors
      );
    }

    if (
      !usuario ||
      usuario.rol !== "administrador" ||
      usuario.activo !== true
    ) {
      return respuesta(
        { ok: false, mensaje: "Acceso denegado" },
        403,
        cors
      );
    }

    const longitud = Number(
      req.headers.get("content-length") ?? "0"
    );

    if (longitud > 2048) {
      return respuesta(
        { ok: false, mensaje: "Solicitud demasiado grande" },
        413,
        cors
      );
    }

    let entrada: unknown;

    try {
      const MAX_DETALLE_BYTES = 2048;
      const lector = req.body?.getReader();

      if (!lector) {
        return respuesta(
          { ok: false, mensaje: "Solicitud vacía" },
          400,
          cors
        );
      }

      let totalBytes = 0;
      const partes: Uint8Array[] = [];

      while (true) {
        const { done, value } = await lector.read();
        if (done) break;

        totalBytes += value.byteLength;

        if (totalBytes > MAX_DETALLE_BYTES) {
          await lector.cancel();
          return respuesta(
            { ok: false, mensaje: "Solicitud demasiado grande" },
            413,
            cors
          );
        }

        partes.push(value);
      }

      const buffer = new Uint8Array(totalBytes);
      let posicion = 0;

      for (const parte of partes) {
        buffer.set(parte, posicion);
        posicion += parte.byteLength;
      }

      entrada = JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(buffer)
      );
    } catch {
      return respuesta(
        { ok: false, mensaje: "JSON inválido" },
        400,
        cors
      );
    }

    if (
      !entrada ||
      typeof entrada !== "object" ||
      Array.isArray(entrada)
    ) {
      return respuesta(
        { ok: false, mensaje: "Solicitud inválida" },
        400,
        cors
      );
    }

    const registroId = (
      entrada as Record<string, unknown>
    ).registro_id;

    if (
      typeof registroId !== "string" ||
      !UUID.test(registroId)
    ) {
      return respuesta(
        { ok: false, mensaje: "ID de inscripción inválido" },
        400,
        cors
      );
    }

    // Obtener inscripción.
    const { data: registro, error: errorRegistro } =
      await admin
        .from("registros")
        .select(
          "id, folio, estado, exento_pago, created_at, evento_id, promotora_id, asesor_id"
        )
        .eq("id", registroId)
        .eq("evento_id", req.headers.get("x-evento-autorizado")!)
        .maybeSingle();

    if (errorRegistro) {
      console.error(errorRegistro.message);

      return respuesta(
        { ok: false, mensaje: "Error consultando inscripción" },
        500,
        cors
      );
    }

    if (!registro) {
      return respuesta(
        { ok: false, mensaje: "Inscripción no encontrada" },
        404,
        cors
      );
    }

    // Consultar relaciones mediante sus IDs reales.
    const [
      resultadoPromotora,
      resultadoAsesor,
      resultadoEvento,
      resultadoPagos,
    ] = await Promise.all([
      admin
        .from("promotoras")
        .select(
          "id, nombres, apellidos, telefono_whatsapp, estado_residencia, foto_path"
        )
        .eq("id", registro.promotora_id)
        .maybeSingle(),

      admin
        .from("asesores")
        .select("id, nombre")
        .eq("id", registro.asesor_id)
        .maybeSingle(),

      admin
        .from("eventos")
        .select("id, nombre")
        .eq("id", registro.evento_id)
        .maybeSingle(),

      admin
        .from("pagos")
        .select(
          "id, importe, referencia, estado, cuenta_destino, comprobante_path, validado_at, created_at"
        )
        .eq("registro_id", registro.id)
        .order("created_at", { ascending: false })
        .limit(20),
    ]);

    const errores = [
      resultadoPromotora.error,
      resultadoAsesor.error,
      resultadoEvento.error,
      resultadoPagos.error,
    ].filter(Boolean);

    if (errores.length > 0) {
      console.error(
        "Error de relaciones:",
        errores.map((e) => e?.message)
      );

      return respuesta(
        {
          ok: false,
          mensaje: "No se pudo obtener el detalle completo",
        },
        500,
        cors
      );
    }

    const promotora = resultadoPromotora.data;
    const pagos = resultadoPagos.data ?? [];

    // Enlaces firmados de solo lectura:
    // duran 60 segundos y no revelan la clave privada.
    async function enlaceTemporal(
      bucket: string,
      ruta: string | null | undefined
    ): Promise<string | null> {
      if (!ruta) return null;

      const { data, error } = await admin.storage
        .from(bucket)
        .createSignedUrl(ruta, 60);

      if (error) {
        console.error(
          `No se pudo firmar archivo de ${bucket}:`,
          error.message
        );
        return null;
      }

      return data?.signedUrl ?? null;
    }

    const fotoUrl = await enlaceTemporal(
      "fotos-promotoras",
      promotora?.foto_path
    );

    const pagosConEnlaces = await Promise.all(
      pagos.map(async (pago) => ({
        id: pago.id,
        importe: pago.importe,
        referencia: pago.referencia,
        estado: pago.estado,
        cuenta_destino: pago.cuenta_destino,
        validado_at: pago.validado_at,
        created_at: pago.created_at,
        comprobante_url: await enlaceTemporal(
          "comprobantes-pago",
          pago.comprobante_path
        ),
      }))
    );

    return respuesta(
      {
        ok: true,
        participante: {
          id: registro.id,
          folio: registro.folio,
          estado: registro.estado,
          exento_pago: registro.exento_pago,
          created_at: registro.created_at,
          promotora: promotora
            ? {
                id: promotora.id,
                nombres: promotora.nombres,
                apellidos: promotora.apellidos,
                telefono_whatsapp:
                  promotora.telefono_whatsapp,
                estado_residencia:
                  promotora.estado_residencia,
                foto_url: fotoUrl,
              }
            : null,
          asesor: resultadoAsesor.data,
          evento: resultadoEvento.data,
          pagos: pagosConEnlaces,
        },
      },
      200,
      cors
    );
  } catch (error) {
    console.error("Error en detalle-participante:", error);

    return respuesta(
      { ok: false, mensaje: "Error interno del servidor" },
      500,
      cors
    );
  }
});
