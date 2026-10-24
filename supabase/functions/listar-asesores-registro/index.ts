import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.3";

// El selector de asesores se utiliza ANTES de iniciar sesión en el formulario
// público. Solamente retorna id y nombre de asesores activos.
// NO admite filtros ni nombres de tablas recibidos del visitante.
const CABECERAS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

function responder(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CABECERAS, "Content-Type": "application/json; charset=utf-8" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CABECERAS });
  if (req.method !== "POST") {
    return responder(405, { ok: false, mensaje: "Método no permitido." });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return responder(503, { ok: false, mensaje: "Servicio de asesores no configurado." });
  }

  try {
    const cliente = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await cliente.from("asesores")
      .select("id, nombre")
      .eq("activo", true)
      .order("nombre", { ascending: true })
      .limit(200);

    if (error) {
      console.error("Error al listar asesores:", error.code ?? "consulta fallida");
      return responder(503, { ok: false, mensaje: "No fue posible consultar los asesores." });
    }

    return responder(200, { ok: true, asesores: data ?? [] });
  } catch (error) {
    console.error("Error inesperado en listar-asesores-registro:", error instanceof Error ? error.message : "desconocido");
    return responder(500, { ok: false, mensaje: "Error temporal al consultar los asesores." });
  }
});
