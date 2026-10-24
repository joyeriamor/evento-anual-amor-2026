
import { serveEvento, RADEVS } from "../_shared/evento.ts";
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const MAX_INTENTOS = 5;
const VENTANA_MINUTOS = 15;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function responder(
  datos: Record<string, unknown>,
  status = 200
) {
  return Response.json(datos, {
    status,
    headers: { ...corsHeaders, "Cache-Control": "no-store" },
  });
}

async function crearHash(valor: string, secreto: string) {
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

serveEvento({ roles: ['administrador'], evento: RADEVS }, async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: { ...corsHeaders, "Cache-Control": "no-store" },
    });
  }

  if (req.method !== "POST") {
    return responder(
      { ok: false, mensaje: "Método no permitido" },
      405
    );
  }

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const secreto = Deno.env.get("REGISTRO_RATE_LIMIT_SECRET");

    if (!url || !serviceKey || !secreto) {
      return responder(
        {
          ok: false,
          mensaje: "Configuración incompleta",
        },
        500
      );
    }

    const encabezado = req.headers.get("x-forwarded-for");

    if (!encabezado) {
      return responder(
        {
          ok: false,
          mensaje: "No se pudo identificar el origen",
        },
        403
      );
    }

    const ip = encabezado.split(",")[0].trim();

    if (
      !ip ||
      ip.length > 45 ||
      !/^[0-9a-fA-F:.]+$/.test(ip)
    ) {
      return responder(
        {
          ok: false,
          mensaje: "Origen no válido",
        },
        403
      );
    }

    const clave = await crearHash(
      `prueba:registro:${RADEVS}:ip:${ip}`,
      secreto
    );

    const supabase = createClient(url, serviceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: permitido, error } = await supabase.rpc(
      "comprobar_limite_registro",
      {
        p_clave: clave,
        p_max_intentos: MAX_INTENTOS,
        p_ventana_minutos: VENTANA_MINUTOS,
      }
    );

    if (error) {
      console.error("Error del limitador:", error.message);

      return responder(
        {
          ok: false,
          mensaje: "No se pudo verificar el límite",
        },
        503
      );
    }

    if (permitido !== true) {
      return responder(
        {
          ok: false,
          mensaje: "Demasiados intentos. Intenta más tarde.",
          limite_activado: true,
        },
        429
      );
    }

    return responder({
      ok: true,
      mensaje: "Solicitud permitida",
      limite_activado: false,
    });
  } catch (error) {
    console.error("Error inesperado:", error);

    return responder(
      {
        ok: false,
        mensaje: "Error al comprobar la seguridad",
      },
      500
    );
  }
});
