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
  "http://localhost:5173",
];

function respuesta(
  body: Record<string, unknown>,
  status: number,
  origin: string
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      Vary: "Origin",
    },
  });
}

serveEvento({ roles: ['administrador'] }, async (req) => {
  const origin = req.headers.get("origin") ?? "";

  if (
    origin &&
    !ORIGENES_PERMITIDOS.includes(origin)
  ) {
    return new Response("Origen no permitido", {
      status: 403,
    });
  }

  const corsOrigin = origin || "http://localhost:5173";

  if (req.method === "OPTIONS") {
    return respuesta({}, 200, corsOrigin);
  }

  if (req.method !== "POST") {
    return respuesta(
      { ok: false, mensaje: "Método no permitido" },
      405,
      corsOrigin
    );
  }

  if (
    !SUPABASE_URL ||
    !SUPABASE_ANON_KEY ||
    !SUPABASE_SERVICE_ROLE_KEY
  ) {
    return respuesta(
      { ok: false, mensaje: "Configuración incompleta" },
      503,
      corsOrigin
    );
  }

  const authorization =
    req.headers.get("authorization") ?? "";

  if (!authorization.startsWith("Bearer ")) {
    return respuesta(
      { ok: false, mensaje: "Sesión requerida" },
      401,
      corsOrigin
    );
  }

  const token = authorization.slice(7).trim();

  if (!token) {
    return respuesta(
      { ok: false, mensaje: "Token inválido" },
      401,
      corsOrigin
    );
  }

  try {
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
      return respuesta(
        { ok: false, mensaje: "Sesión inválida" },
        401,
        corsOrigin
      );
    }

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

    const { data, error } = await adminClient
      .from("usuarios")
      .select("nombre, rol, activo")
      .eq("id", user.id)
      .maybeSingle();

    if (error) {
      console.error("Error verificando rol:", error.message);

      return respuesta(
        {
          ok: false,
          mensaje: "No se pudo verificar el acceso",
        },
        500,
        corsOrigin
      );
    }

    if (
      !data ||
      !data.activo ||
      data.rol !== "administrador"
    ) {
      return respuesta(
        {
          ok: false,
          mensaje: "No tienes permisos de administrador",
        },
        403,
        corsOrigin
      );
    }

    return respuesta(
      {
        ok: true,
        autorizado: true,
        usuario: {
          id: user.id,
          nombre: data.nombre,
          rol: data.rol,
        },
      },
      200,
      corsOrigin
    );
  } catch (error) {
    console.error("Error interno:", error);

    return respuesta(
      {
        ok: false,
        mensaje: "Error interno del servidor",
      },
      500,
      corsOrigin
    );
  }
});
