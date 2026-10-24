import { serveEvento, RADEVS } from "../_shared/evento.ts";


import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function responder(
  data: Record<string, unknown>,
  status = 200
) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Accion = "cortesia" | "recuperar" | "reemitir";

serveEvento({ roles: ['administrador'], evento: RADEVS }, async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return responder(
      { ok: false, error: "Método no permitido" },
      405
    );
  }

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get(
      "SUPABASE_SERVICE_ROLE_KEY"
    );

    if (!url || !serviceKey) {
      return responder(
        { ok: false, error: "Configuración incompleta" },
        500
      );
    }

    const authorization = req.headers.get("Authorization");
    const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];

    if (!token) {
      return responder(
        { ok: false, error: "Sesión requerida" },
        401
      );
    }

    const admin = createClient(url, serviceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: authData, error: authError } =
      await admin.auth.getUser(token);

    if (authError || !authData.user) {
      return responder(
        { ok: false, error: "Sesión inválida" },
        401
      );
    }

    const { data: usuario, error: usuarioError } =
      await admin
        .from("usuarios")
        .select("rol, activo")
        .eq("id", authData.user.id)
        .single();

    if (
      usuarioError ||
      usuario?.rol !== "administrador" ||
      usuario?.activo !== true
    ) {
      return responder(
        { ok: false, error: "Acceso denegado" },
        403
      );
    }

    // Limitar solicitudes administrativas a 4 KB.
    const MAX_INVITACION_BYTES = 4096;
    let body: Record<string, unknown>;

    try {
      const lector = req.body?.getReader();

      if (!lector) {
        return responder({ ok: false, error: "JSON invalido" }, 400);
      }

      const partes: Uint8Array[] = [];
      let total = 0;

      while (true) {
        const { done, value } = await lector.read();
        if (done) break;

        total += value.byteLength;

        if (total > MAX_INVITACION_BYTES) {
          await lector.cancel().catch(() => {});
          return responder(
            { ok: false, error: "Solicitud demasiado grande" },
            413
          );
        }

        partes.push(value);
      }

      const buffer = new Uint8Array(total);
      let posicion = 0;

      for (const parte of partes) {
        buffer.set(parte, posicion);
        posicion += parte.byteLength;
      }

      const parsed: unknown = JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(buffer)
      );

      if (
        typeof parsed !== "object" ||
        parsed === null ||
        Array.isArray(parsed)
      ) {
        throw new Error("JSON invalido");
      }

      body = parsed as Record<string, unknown>;

    } catch {
      return responder({ ok: false, error: "JSON invalido" }, 400);
    }

    const registroId = body.registro_id;
    const accion = body.accion;

    if (
      typeof registroId !== "string" ||
      !uuidRegex.test(registroId)
    ) {
      return responder(
        { ok: false, error: "ID de inscripción inválido" },
        400
      );
    }

    if (
      accion !== "cortesia" &&
      accion !== "recuperar" &&
      accion !== "reemitir"
    ) {
      return responder(
        { ok: false, error: "Acción inválida" },
        400
      );
    }

    const accionValidada = accion as Accion;
    const administradorId = authData.user.id;

    const { data: objetivo, error: objetivoError } = await admin.from("registros")
      .select("id").eq("id", registroId).eq("evento_id", RADEVS).maybeSingle();
    if (objetivoError) return responder({ ok: false, error: "No se pudo verificar la inscripción" }, 503);
    if (!objetivo) return responder({ ok: false, error: "Inscripción no encontrada" }, 404);

    let resultado: unknown;
    let errorRPC: { message: string } | null = null;

    if (accionValidada === "cortesia") {
      const respuesta = await admin.rpc(
        "autorizar_cortesia_admin",
        {
          p_registro_id: registroId,
          p_admin_id: administradorId,
        }
      );

      resultado = respuesta.data;
      errorRPC = respuesta.error;
    } else {
      const respuesta = await admin.rpc(
        "recuperar_invitacion_admin",
        {
          p_registro_id: registroId,
          p_admin_id: administradorId,
          p_reemitir: accionValidada === "reemitir",
        }
      );

      resultado = respuesta.data;
      errorRPC = respuesta.error;
    }

    if (errorRPC) {
      console.error(
        "Error al administrar invitación:",
        errorRPC.message
      );

      return responder(
        {
          ok: false,
          error:
            "No se pudo completar la operación. Verifica el estado de la inscripción.",
        },
        400
      );
    }

    return responder({
      ok: true,
      resultado,
    });
  } catch (error) {
    console.error("Error interno:", error);

    return responder(
      { ok: false, error: "Error interno del servidor" },
      500
    );
  }
});
