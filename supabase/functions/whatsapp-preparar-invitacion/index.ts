import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const ALLOWED_ORIGINS = new Set([
  "https://joyeriamor.github.io",
  "http://localhost:5173",
]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function response(status: number, data: Record<string, unknown>, origin: string) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...(ALLOWED_ORIGINS.has(origin) ? {
        "Access-Control-Allow-Origin": origin, Vary: "Origin",
      } : {}),
      "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-supabase-api-version",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin") ?? "";
  if (origin && !ALLOWED_ORIGINS.has(origin)) return response(403, { ok: false, error: "Origen no autorizado" }, origin);
  if (req.method === "OPTIONS") return response(200, { ok: true }, origin);
  if (req.method !== "POST") return response(405, { ok: false, error: "Método no permitido" }, origin);

  const token = req.headers.get("authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if (!token) return response(401, { ok: false, error: "Sesión requerida" }, origin);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return response(503, { ok: false, error: "Configuración de servidor incompleta" }, origin);

  try {
    const bodyText = await req.text();
    if (bodyText.length > 1024) return response(413, { ok: false, error: "Solicitud demasiado grande" }, origin);
    let body: Record<string, unknown>;
    try { body = JSON.parse(bodyText); } catch {
      return response(400, { ok: false, error: "Solicitud JSON inválida" }, origin);
    }
    if (!body || typeof body !== "object" || Array.isArray(body) ||
        typeof body.registro_id !== "string" || !UUID.test(body.registro_id) ||
        (body.preparar !== undefined && typeof body.preparar !== "boolean") ||
        Object.keys(body).some((k) => !["registro_id", "preparar"].includes(k))) {
      return response(400, { ok: false, error: "Identificador de registro o parámetros inválidos" }, origin);
    }

    const db = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: identity, error: authError } = await db.auth.getUser(token);
    if (authError || !identity.user) return response(401, { ok: false, error: "Sesión inválida" }, origin);

    const { data: admin, error: adminError } = await db.from("usuarios")
      .select("rol,activo").eq("id", identity.user.id).maybeSingle();
    if (adminError) return response(503, { ok: false, error: "No fue posible verificar el perfil" }, origin);
    if (!admin?.activo || admin.rol !== "administrador") {
      return response(403, { ok: false, error: "Operación exclusiva de administradores" }, origin);
    }

    const {data,error}=await db.rpc("whatsapp_preparar_admin_interno",{
      p_registro:body.registro_id,p_admin:identity.user.id,p_preparar:body.preparar===true,
    });
    if(error)return response(error.code==="P0001"?403:503,{ok:false,error:"Operación no disponible o no autorizada"},origin);
    return response(200,data,origin);
  } catch (error) {
    console.error("whatsapp-preparar:", error instanceof Error ? error.name : "error");
    return response(503, { ok: false, error: "No fue posible completar la revisión" }, origin);
  }
});
