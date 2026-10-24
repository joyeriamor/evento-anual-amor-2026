
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

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
    },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return responder(
      {
        ok: false,
        error: "Método no permitido",
      },
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
        {
          ok: false,
          error: "Configuración incompleta",
        },
        500
      );
    }

    // Obtener token del usuario autenticado.
    const authorization =
      req.headers.get("Authorization");

    const token = authorization?.match(
      /^Bearer\s+(.+)$/i
    )?.[1];

    if (!token) {
      return responder(
        {
          ok: false,
          error: "Sesión requerida",
        },
        401
      );
    }

    // Cliente privado del servidor.
    const admin = createClient(url, serviceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    // Verificar el token con Supabase Auth.
    const { data: authData, error: authError } =
      await admin.auth.getUser(token);

    if (authError || !authData.user) {
      return responder(
        {
          ok: false,
          error: "Sesión inválida",
        },
        401
      );
    }

    // Comprobar que sea administrador activo.
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
        {
          ok: false,
          error: "Acceso denegado",
        },
        403
      );
    }

    // Leer JSON con límite máximo de 4 KB.
    const MAX_PAGO_BYTES = 4096;
    let body: Record<string, unknown>;

    try {
      const lector = req.body?.getReader();

      if (!lector) {
        return responder({ ok: false, error: "JSON inválido" }, 400);
      }

      const partes: Uint8Array[] = [];
      let total = 0;

      while (true) {
        const { done, value } = await lector.read();
        if (done) break;

        total += value.byteLength;

        if (total > MAX_PAGO_BYTES) {
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
        throw new Error("JSON inválido");
      }

      body = parsed as Record<string, unknown>;

    } catch {
      return responder(
        { ok: false, error: "JSON inválido" },
        400
      );
    }

    const pagoId = body.pago_id;
    const accion = body.accion;
    const motivo = body.motivo ?? null;

    // UUID CORREGIDO:
    // 8-4-4-4-12 caracteres hexadecimales.
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    if (
      typeof pagoId !== "string" ||
      !uuidRegex.test(pagoId)
    ) {
      return responder(
        {
          ok: false,
          error: "ID de pago inválido",
        },
        400
      );
    }

    // Acciones permitidas.
    if (
      accion !== "aprobar" &&
      accion !== "rechazar"
    ) {
      return responder(
        {
          ok: false,
          error: "Acción inválida",
        },
        400
      );
    }

    // Validar motivo.
    if (
      motivo !== null &&
      typeof motivo !== "string"
    ) {
      return responder(
        {
          ok: false,
          error: "Motivo inválido",
        },
        400
      );
    }

    if (
      accion === "rechazar" &&
      (
        typeof motivo !== "string" ||
        motivo.trim().length < 5
      )
    ) {
      return responder(
        {
          ok: false,
          error:
            "Indica un motivo de al menos 5 caracteres",
        },
        400
      );
    }

    if (
      typeof motivo === "string" &&
      motivo.length > 500
    ) {
      return responder(
        {
          ok: false,
          error: "Motivo demasiado largo",
        },
        400
      );
    }

    // Identidad obtenida del JWT verificado,
    // nunca del cuerpo enviado por el navegador.
    const administradorId = authData.user.id;

    // Autorizacion exclusiva de Chiapas.
    // El ID del evento es fijo en el servidor.
    // Nunca confiar en un evento_id enviado por el cliente.
    const { data: asignacionChiapas, error: errorAsignacionChiapas } =
      await admin
        .from("usuarios_eventos")
        .select("usuario_id")
        .eq("usuario_id", administradorId)
        .eq("evento_id", "3dc92160-79af-4bf7-b770-263038e88900")
        .eq("activo", true)
        .maybeSingle();

    if (errorAsignacionChiapas) {
      console.error(
        "Error verificando asignacion Chiapas:",
        errorAsignacionChiapas.message
      );

      return responder(
        {
          ok: false,
          error: "No se pudo verificar el acceso a Chiapas",
        },
        500
      );
    }

    if (!asignacionChiapas) {
      return responder(
        {
          ok: false,
          error: "No tienes permiso para administrar Chiapas",
        },
        403
      );
    }


    // RPC protegida: únicamente service_role.
    // PostgreSQL comprueba nuevamente el rol
    // y procesa pago + auditoría en una transacción.
    const { data, error } = await admin.rpc(
      "validar_pago_admin_chiapas",
      {
        p_pago_id: pagoId,
        p_accion: accion,
        p_motivo: motivo,
        p_admin_id: administradorId,
      }
    );

    if (error) {
      console.error(
        "Error al validar pago:",
        error
      );

      const conflicto =
        error.message.includes("ya fue procesado") ||
        error.message.includes("no está pendiente");

      return responder(
        {
          ok: false,
          error: conflicto
            ? "Este pago ya fue procesado"
            : "No se pudo validar el pago",
        },
        conflicto ? 409 : 400
      );
    }

    return responder({
      ok: true,
      resultado: data,
    });

  } catch (error) {
    console.error(
      "Error inesperado:",
      error
    );

    return responder(
      {
        ok: false,
        error: "Error interno del servidor",
      },
      500
    );
  }
});
