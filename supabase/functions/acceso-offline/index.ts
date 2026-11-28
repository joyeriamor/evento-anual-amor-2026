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
type Fila = { foto_path?: string | null; foto_url?: string | null };

serveEvento({ roles: ["administrador", "acceso"] }, async (req) => {
  try {
    const body = await req.json();
    const evento = req.headers.get("x-evento-autorizado");
    if (!uuid(evento) || !uuid(body.dispositivo_id)) {
      return json({ ok: false, error: "Evento o equipo inválido" }, 400);
    }
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    // SQL receives the real JWT so auth.uid() remains authoritative.
    const auth = createClient(url, anon, {
      global: { headers: { Authorization: req.headers.get("authorization")! } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    if (body.accion === "descargar") {
      const { data, error } = await auth.rpc("offline_descargar", {
        p_evento_id: evento, p_dispositivo_id: body.dispositivo_id,
      });
      if (error || !data?.ok || !Array.isArray(data.participantes)) {
        return json({ ok: false, error: "No fue posible preparar el evento. Revisa sesión, asignación y fecha." }, 403);
      }
      const filas: Fila[] = data.participantes;
      const paths = [...new Set(filas.map(f => f.foto_path).filter((p): p is string =>
        typeof p === "string" && p.length > 0))];
      const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const firmadas = new Map<string, string>();
      for (let i = 0; i < paths.length; i += 100) {
        const { data: signed, error: fallo } = await service.storage
          .from(Deno.env.get("FOTO_BUCKET") || "fotos-promotoras")
          .createSignedUrls(paths.slice(i, i + 100), 3600);
        if (fallo) return json({ ok: false, error: "No se pudieron preparar las fotografías." }, 503);
        for (const item of signed || []) {
          if (item.path && item.signedUrl && !item.error) firmadas.set(item.path, item.signedUrl);
        }
      }
      // No caller-supplied file path is signed; all paths came from the event RPC.
      for (const fila of filas) {
        fila.foto_url = fila.foto_path ? firmadas.get(fila.foto_path) ?? null : null;
        if (fila.foto_path && !fila.foto_url) {
          return json({ ok: false, error: "Falta una fotografía del evento. Se conserva la descarga anterior." }, 409);
        }
      }
      return json(data);
    }
    if (body.accion !== "sincronizar" || !uuid(body.paquete_id) ||
        !Array.isArray(body.accesos) || body.accesos.length < 1 || body.accesos.length > 25) {
      return json({ ok: false, error: "Operación offline inválida" }, 400);
    }
    const ids = new Set<string>();
    for (const entrada of body.accesos) {
      if (!entrada || !uuid(entrada.operacion_id) || ids.has(entrada.operacion_id) ||
          typeof entrada.token !== "string" || !/^[a-fA-F0-9]{64}$/.test(entrada.token) ||
          typeof entrada.ingresado_at !== "string" || entrada.ingresado_at.length > 50 ||
          !Number.isFinite(Date.parse(entrada.ingresado_at))) {
        return json({ ok: false, error: "Entrada offline inválida" }, 400);
      }
      ids.add(entrada.operacion_id);
    }
    const resultados = [];
    for (const entrada of body.accesos) {
      const { data, error } = await auth.rpc("offline_sincronizar", {
        p_evento_id: evento, p_dispositivo_id: body.dispositivo_id,
        p_paquete_id: body.paquete_id, p_operacion_id: entrada.operacion_id,
        p_token: entrada.token, p_ingresado_at: entrada.ingresado_at,
      });
      // An earlier row may already be committed. The same operation ID makes retry safe.
      if (error || !data || typeof data.estado !== "string") {
        return json({ ok: false, error: "No se confirmó todo el envío. Inicia sesión y vuelve a sincronizar; tus entradas se conservan." }, 409);
      }
      resultados.push({ operacion_id: entrada.operacion_id, ok: data.ok === true, estado: data.estado });
    }
    return json({ ok: true, resultados });
  } catch {
    // Do not log bearer tokens, QR contents or participant data.
    return json({ ok: false, error: "No se pudo completar la operación offline." }, 503);
  }
});
