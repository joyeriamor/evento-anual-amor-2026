import { createClient } from "npm:@supabase/supabase-js@2.117.3";
import { serveEvento } from "../_shared/evento.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { ...cors, "Content-Type": "application/json" },
});
const uuid = (v: unknown): v is string => typeof v === "string" &&
  /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v);

serveEvento({ roles: ["administrador", "acceso"] }, async (req) => {
  try {
    const body = await req.json();
    const evento = req.headers.get("x-evento-autorizado");
    if (!uuid(evento) || body.accion !== "sincronizar" || !uuid(body.dispositivo_id) ||
        !uuid(body.paquete_id) || !Array.isArray(body.accesos) ||
        body.accesos.length < 1 || body.accesos.length > 25) {
      return json({ ok: false, error: "Operación manual inválida" }, 400);
    }
    const ids = new Set<string>();
    for (const entrada of body.accesos) {
      if (!entrada || !uuid(entrada.operacion_id) || ids.has(entrada.operacion_id.toLowerCase()) ||
          !uuid(entrada.registro_id) || !uuid(entrada.invitacion_id) || entrada.identidad_confirmada !== true ||
          typeof entrada.ingresado_at !== "string" || entrada.ingresado_at.length > 50 ||
          !Number.isFinite(Date.parse(entrada.ingresado_at))) {
        return json({ ok: false, error: "Entrada manual inválida" }, 400);
      }
      ids.add(entrada.operacion_id.toLowerCase());
    }
    // SQL receives only the validated user's JWT; it rechecks all authorization.
    const auth = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("authorization")! } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const resultados = [];
    for (const entrada of body.accesos) {
      const { data, error } = await auth.rpc("offline_sincronizar_manual", {
        p_evento_id: evento, p_dispositivo_id: body.dispositivo_id, p_paquete_id: body.paquete_id,
        p_operacion_id: entrada.operacion_id, p_registro_id: entrada.registro_id,
        p_invitacion_id: entrada.invitacion_id, p_ingresado_at: entrada.ingresado_at,
        p_identidad_confirmada: entrada.identidad_confirmada,
      });
      if (error || !data || typeof data.estado !== "string") {
        return json({ ok: false, error: "No se confirmó todo el envío. Vuelve a sincronizar; tus entradas se conservan." }, 409);
      }
      resultados.push({ operacion_id: entrada.operacion_id, ok: data.ok === true, estado: data.estado });
    }
    return json({ ok: true, resultados });
  } catch {
    return json({ ok: false, error: "No se pudo completar la sincronización manual." }, 503);
  }
});
