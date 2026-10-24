
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.117.3";

// INTERRUPTOR PRINCIPAL.
// No cambiar a true hasta completar la seguridad
// y las pruebas de inscripción.
const REGISTROS_HABILITADOS = false;

const MAX_ARCHIVO = 5 * 1024 * 1024;
const MAX_SOLICITUD = 11 * 1024 * 1024;
const MAX_INTENTOS = 5;
const VENTANA_MINUTOS = 15;

const ORIGENES_PERMITIDOS = [
  "http://localhost:5173",
];

const CUENTAS_VALIDAS = [
  "bbva-laura",
  "bbva-rufino",
  "coppel-laura",
  "coppel-rufino",
];

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type Cliente = SupabaseClient;

function cors(req: Request) {
  const origen = req.headers.get("origin") ?? "";

  return {
    "Access-Control-Allow-Origin":
      ORIGENES_PERMITIDOS.includes(origen) ? origen : "null",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function responder(
  req: Request,
  datos: Record<string, unknown>,
  status = 200
) {
  return Response.json(datos, {
    status,
    headers: cors(req),
  });
}

function obtenerIp(req: Request): string | null {
  // Supabase puede proporcionar esta cabecera mediante
  // su infraestructura. No se considera prueba
  // criptográfica del origen.
  const encabezado = req.headers.get("x-forwarded-for");

  if (!encabezado) return null;

  const ip = encabezado.split(",")[0].trim();

  if (
    !ip ||
    ip.length > 45 ||
    !/^[0-9a-fA-F:.]+$/.test(ip)
  ) {
    return null;
  }

  return ip;
}

async function crearHash(
  valor: string,
  secreto: string
): Promise<string> {
  const encoder = new TextEncoder();

  const clave = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secreto),
    {
      name: "HMAC",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const firma = await crypto.subtle.sign(
    "HMAC",
    clave,
    encoder.encode(valor)
  );

  return Array.from(new Uint8Array(firma))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function comprobarLimite(
  req: Request,
  cliente: Cliente
): Promise<{
  permitido: boolean;
  status: number;
  mensaje: string;
}> {
  const secreto = Deno.env.get("REGISTRO_RATE_LIMIT_SECRET");

  if (!secreto) {
    return {
      permitido: false,
      status: 503,
      mensaje: "Control de solicitudes no configurado",
    };
  }

  const ip = obtenerIp(req);

  if (!ip) {
    return {
      permitido: false,
      status: 403,
      mensaje: "No se pudo identificar el origen",
    };
  }

  const clave = await crearHash(
    `registro:ip:${ip}`,
    secreto
  );

  const { data, error } = await cliente.rpc(
    "comprobar_limite_registro",
    {
      p_clave: clave,
      p_max_intentos: MAX_INTENTOS,
      p_ventana_minutos: VENTANA_MINUTOS,
    }
  );

  if (error) {
    console.error("Error del limitador:", error.message);

    return {
      permitido: false,
      status: 503,
      mensaje: "No se pudo verificar el límite",
    };
  }

  if (data !== true) {
    return {
      permitido: false,
      status: 429,
      mensaje: "Demasiados intentos. Intenta más tarde.",
    };
  }

  return {
    permitido: true,
    status: 200,
    mensaje: "Solicitud permitida",
  };
}

function obtenerCliente(): Cliente {
  const url = Deno.env.get("SUPABASE_URL");
  const clave = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !clave) {
    throw new Error("Configuración de Supabase incompleta");
  }

  return createClient(url, clave, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

function texto(
  form: FormData,
  campo: string,
  maximo: number
): string {
  const valor = form.get(campo);

  if (typeof valor !== "string") {
    throw new Error(`Falta el campo ${campo}`);
  }

  const limpio = valor.trim();

  if (!limpio || limpio.length > maximo) {
    throw new Error(`Campo inválido: ${campo}`);
  }

  return limpio;
}

async function validarImagen(
  valor: FormDataEntryValue | null,
  campo: string
) {
  if (!(valor instanceof File)) {
    throw new Error(`Falta ${campo}`);
  }

  if (valor.size < 12 || valor.size > MAX_ARCHIVO) {
    throw new Error(`${campo}: tamaño no permitido`);
  }

  const inicio = new Uint8Array(
    await valor.slice(0, 12).arrayBuffer()
  );

  const jpg =
    inicio[0] === 0xff &&
    inicio[1] === 0xd8 &&
    inicio[2] === 0xff;

  const png =
    inicio[0] === 0x89 &&
    inicio[1] === 0x50 &&
    inicio[2] === 0x4e &&
    inicio[3] === 0x47 &&
    inicio[4] === 0x0d &&
    inicio[5] === 0x0a &&
    inicio[6] === 0x1a &&
    inicio[7] === 0x0a;

  const webp =
    String.fromCharCode(...inicio.slice(0, 4)) === "RIFF" &&
    String.fromCharCode(...inicio.slice(8, 12)) === "WEBP";

  if (jpg && valor.type === "image/jpeg") {
    return {
      archivo: valor,
      tipo: "image/jpeg",
      extension: "jpg",
    };
  }

  if (png && valor.type === "image/png") {
    return {
      archivo: valor,
      tipo: "image/png",
      extension: "png",
    };
  }

  if (webp && valor.type === "image/webp") {
    return {
      archivo: valor,
      tipo: "image/webp",
      extension: "webp",
    };
  }

  throw new Error(`${campo}: imagen no válida`);
}

async function verificarTurnstile(
  token: string,
  solicitudId: string
): Promise<boolean> {
  const secreto = Deno.env.get("TURNSTILE_SECRET_KEY");

  if (!secreto) {
    throw new Error("Turnstile no configurado");
  }

  const parametros = new URLSearchParams({
    secret: secreto,
    response: token,
    idempotency_key: solicitudId,
  });

  const respuesta = await fetch(
    "https://challenges.cloudflare.com/turnstile/v0/siteverify",
    {
      method: "POST",
      body: parametros,
      signal: AbortSignal.timeout(10000),
    }
  );

  if (!respuesta.ok) {
    throw new Error("No se pudo verificar Turnstile");
  }

  const resultado = await respuesta.json();

  return (
    resultado.success === true &&
    resultado.hostname === "localhost"
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: cors(req),
    });
  }

  if (req.method !== "POST") {
    return responder(
      req,
      { ok: false, mensaje: "Método no permitido" },
      405
    );
  }

  const origen = req.headers.get("origin");

  if (
    origen &&
    !ORIGENES_PERMITIDOS.includes(origen)
  ) {
    return responder(
      req,
      { ok: false, mensaje: "Origen no permitido" },
      403
    );
  }

  const tipo = req.headers.get("content-type") ?? "";

  // PRUEBA INTEGRADA:
  // No recibe archivos, nombres ni teléfonos.
  if (tipo.includes("application/json")) {
    try {
      const body = await req.json();

      if (body?.accion !== "probar-seguridad") {
        return responder(
          req,
          { ok: false, mensaje: "Acción no disponible" },
          400
        );
      }

      // No permitir campos adicionales en esta prueba.
      if (
        typeof body !== "object" ||
        body === null ||
        Array.isArray(body) ||
        Object.keys(body).length !== 1
      ) {
        return responder(
          req,
          { ok: false, mensaje: "Solicitud inválida" },
          400
        );
      }

      const cliente = obtenerCliente();
      const limite = await comprobarLimite(req, cliente);

      return responder(
        req,
        {
          ok: limite.permitido,
          mensaje: limite.mensaje,
          limite_activado: limite.status === 429,
          registro_habilitado: false,
        },
        limite.status
      );
    } catch (error) {
      console.error("Error en prueba de seguridad:", error);

      return responder(
        req,
        { ok: false, mensaje: "Error de seguridad" },
        500
      );
    }
  }

  // El registro real sigue deshabilitado.
  // Ninguna fotografía ni comprobante se procesa
  // mientras este interruptor esté en false.
  if (!REGISTROS_HABILITADOS) {
    return responder(req, {
      ok: true,
      mensaje: "Backend preparado. Inscripciones aún cerradas.",
      registro_habilitado: false,
    });
  }

  let cliente: Cliente | null = null;
  let inscripcionCreada = false;

  const archivosSubidos: {
    bucket: string;
    path: string;
  }[] = [];

  try {
    // El límite se comprueba ANTES de leer archivos.
    cliente = obtenerCliente();

    const limite = await comprobarLimite(req, cliente);

    if (!limite.permitido) {
      return responder(
        req,
        { ok: false, mensaje: limite.mensaje },
        limite.status
      );
    }

    const longitudTexto = req.headers.get("content-length");
    const longitud = longitudTexto
      ? Number(longitudTexto)
      : NaN;

    if (
      !Number.isFinite(longitud) ||
      longitud < 1 ||
      longitud > MAX_SOLICITUD
    ) {
      return responder(
        req,
        { ok: false, mensaje: "Tamaño no permitido" },
        413
      );
    }

    if (!tipo.includes("multipart/form-data")) {
      return responder(
        req,
        { ok: false, mensaje: "Formulario requerido" },
        415
      );
    }

    const form = await req.formData();

    const nombres = texto(form, "nombres", 100);
    const apellidos = texto(form, "apellidos", 100);
    const telefono = texto(form, "whatsapp", 10);
    const estado = texto(form, "estado", 60);
    const asesorId = texto(form, "asesor_id", 36);
    const eventoId = "43e67bda-d19d-4c0e-a639-e85f2d62f294";
    const eventoSolicitado = texto(form, "evento_id", 36);
    if (eventoSolicitado && eventoSolicitado !== eventoId) {
      return responder(req, { ok: false, mensaje: "Evento no autorizado" }, 403);
    }
    const cuentaDestino = texto(
      form,
      "cuenta_destino",
      40
    );
    const solicitudId = texto(
      form,
      "solicitud_id",
      36
    );
    const privacidadVersion = texto(
      form,
      "privacidad_version",
      40
    );
    const token = texto(
      form,
      "turnstile_token",
      2048
    );

    if (
      nombres.length < 2 ||
      apellidos.length < 2 ||
      !/^[0-9]{10}$/.test(telefono) ||
      !UUID_REGEX.test(asesorId) ||
      !UUID_REGEX.test(eventoId) ||
      !UUID_REGEX.test(solicitudId) ||
      !CUENTAS_VALIDAS.includes(cuentaDestino)
    ) {
      throw new Error("Datos de inscripción inválidos");
    }

    const foto = await validarImagen(
      form.get("foto"),
      "Fotografía"
    );

    const comprobante = await validarImagen(
      form.get("comprobante"),
      "Comprobante"
    );

    const seguridadValida = await verificarTurnstile(
      token,
      solicitudId
    );

    if (!seguridadValida) {
      return responder(
        req,
        {
          ok: false,
          mensaje: "Verificación de seguridad rechazada",
        },
        403
      );
    }

    const { data: evento, error: errorEvento } =
      await cliente
        .from("eventos")
        .select("id")
        .eq("id", eventoId)
        .eq("estado", "activo")
        .maybeSingle();

    if (errorEvento || !evento) {
      return responder(
        req,
        { ok: false, mensaje: "Evento no disponible" },
        400
      );
    }

    const { data: asesor, error: errorAsesor } =
      await cliente
        .from("asesores")
        .select("id")
        .eq("id", asesorId)
        .eq("activo", true)
        .maybeSingle();

    if (errorAsesor || !asesor) {
      return responder(
        req,
        { ok: false, mensaje: "Asesor no válido" },
        400
      );
    }

    const carpeta = crypto.randomUUID();

    const fotoPath =
      `${eventoId}/${carpeta}/foto.${foto.extension}`;

    const comprobantePath =
      `${eventoId}/${carpeta}/comprobante.${comprobante.extension}`;

    const { error: errorFoto } = await cliente.storage
      .from("fotos-promotoras")
      .upload(fotoPath, foto.archivo, {
        contentType: foto.tipo,
        upsert: false,
      });

    if (errorFoto) {
      throw new Error("No se pudo guardar la fotografía");
    }

    archivosSubidos.push({
      bucket: "fotos-promotoras",
      path: fotoPath,
    });

    const { error: errorComprobante } =
      await cliente.storage
        .from("comprobantes-pago")
        .upload(comprobantePath, comprobante.archivo, {
          contentType: comprobante.tipo,
          upsert: false,
        });

    if (errorComprobante) {
      throw new Error("No se pudo guardar el comprobante");
    }

    archivosSubidos.push({
      bucket: "comprobantes-pago",
      path: comprobantePath,
    });

    const { data: registroId, error: errorRegistro } =
      await cliente.rpc("crear_inscripcion", {
        p_evento_id: eventoId,
        p_nombres: nombres,
        p_apellidos: apellidos,
        p_telefono: telefono,
        p_estado: estado,
        p_asesor_id: asesorId,
        p_foto_path: fotoPath,
        p_comprobante_path: comprobantePath,
        p_cuenta_destino: cuentaDestino,
        p_solicitud_id: solicitudId,
        p_privacidad_version: privacidadVersion,
      });

    if (errorRegistro) {
      throw new Error("No se pudo crear la inscripción");
    }

    inscripcionCreada = true;

    return responder(
      req,
      {
        ok: true,
        mensaje:
          "Inscripción recibida, pendiente de revisión",
        registro_id: registroId,
      },
      201
    );
  } catch (error) {
    console.error("Error de inscripción:", error);

    return responder(
      req,
      {
        ok: false,
        mensaje: "No se pudo completar la inscripción",
      },
      400
    );
  } finally {
    if (cliente && !inscripcionCreada) {
      for (const archivo of archivosSubidos) {
        const { error } = await cliente.storage
          .from(archivo.bucket)
          .remove([archivo.path]);

        if (error) {
          console.error(
            "No se pudo limpiar archivo:",
            archivo.bucket,
            archivo.path,
            error.message
          );
        }
      }
    }
  }
});
