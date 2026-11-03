import QRCode from "npm:qrcode@1.5.4";
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const EVENTOS: Record<string, string> = {
  "43e67bda-d19d-4c0e-a639-e85f2d62f294": "emitir_invitacion_admin_interna",
  "3dc92160-79af-4bf7-b770-263038e88900": "emitir_invitacion_chiapas_interna",
};
const ALLOWED_ORIGINS = new Set([
  "https://joyeriamor.github.io",
  "http://localhost:5173",
]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function headers(origin: string): HeadersInit {
  return {
    "Cache-Control": "private, no-store, max-age=0",
    "Pragma": "no-cache",
    "X-Content-Type-Options": "nosniff",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-supabase-api-version",
    ...(ALLOWED_ORIGINS.has(origin) ? {
      "Access-Control-Allow-Origin": origin,
      "Vary": "Origin",
    } : {}),
  };
}
function reply(status: number, data: Record<string, unknown>, origin: string): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...headers(origin), "Content-Type": "application/json; charset=utf-8" },
  });
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin") ?? "";
  if (origin && !ALLOWED_ORIGINS.has(origin)) {
    return reply(403, { ok: false, error: "Origen no permitido" }, origin);
  }
  if (req.method === "OPTIONS") return reply(200, { ok: true }, origin);
  if (req.method !== "POST") return reply(405, { ok: false, error: "Método no permitido" }, origin);

  const accessToken = req.headers.get("authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if (!accessToken) return reply(401, { ok: false, error: "Sesión requerida" }, origin);
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply(503, { ok: false, error: "Configuración incompleta" }, origin);

  try {
    if (!req.headers.get("content-type")?.toLowerCase().startsWith("application/json")) {
      return reply(415, { ok: false, error: "Se requiere JSON" }, origin);
    }
    const textBody = await req.text();
    if (textBody.length > 1024) return reply(413, { ok: false, error: "Solicitud demasiado grande" }, origin);
    let body: unknown;
    try { body = JSON.parse(textBody); } catch {
      return reply(400, { ok: false, error: "JSON inválido" }, origin);
    }
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return reply(400, { ok: false, error: "Datos inválidos" }, origin);
    }
    const inputs = body as Record<string, unknown>;
    if (typeof inputs.registro_id !== "string" || !UUID.test(inputs.registro_id) ||
      Object.keys(inputs).some((k) => k !== "registro_id")) {
      return reply(400, { ok: false, error: "registro_id inválido" }, origin);
    }

    const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: userResult, error: userError } = await db.auth.getUser(accessToken);
    if (userError || !userResult.user) return reply(401, { ok: false, error: "Sesión inválida" }, origin);

    const userId = userResult.user.id;
    const { data: actor, error: actorError } = await db.from("usuarios")
      .select("rol,activo").eq("id", userId).maybeSingle();
    if (actorError) return reply(503, { ok: false, error: "No se pudo validar el administrador" }, origin);
    if (actor?.rol !== "administrador" || actor.activo !== true) {
      return reply(403, { ok: false, error: "Solo administradores autorizados" }, origin);
    }

    const { data: registro, error: registroError } = await db.from("registros")
      .select("id,evento_id,estado,es_prueba,exento_pago").eq("id", inputs.registro_id).maybeSingle();
    if (registroError) return reply(503, { ok: false, error: "No se pudo consultar la inscripción" }, origin);
    if (!registro) return reply(404, { ok: false, error: "Inscripción no encontrada" }, origin);
    const rpc = EVENTOS[registro.evento_id];
    if (!rpc || registro.estado !== "confirmado" || registro.es_prueba === true) {
      return reply(409, { ok: false, error: "La inscripción no está confirmada para el evento" }, origin);
    }

    const { data: acceso, error: accesoError } = await db.from("usuarios_eventos")
      .select("evento_id").eq("usuario_id", userId).eq("evento_id", registro.evento_id)
      .eq("activo", true).maybeSingle();
    if (accesoError) return reply(503, { ok: false, error: "No se pudo validar el permiso del evento" }, origin);
    if (!acceso) return reply(403, { ok: false, error: "Sin acceso al evento" }, origin);

    if (registro.exento_pago !== true) {
      const { data: pago, error: pagoError } = await db.from("pagos")
        .select("id").eq("registro_id", registro.id).eq("estado", "validado").maybeSingle();
      if (pagoError) return reply(503, { ok: false, error: "No se pudo revisar el pago" }, origin);
      if (!pago) return reply(409, { ok: false, error: "No hay pago validado o cortesía autorizada" }, origin);
    }

    // No se genera ni reemite una invitación: únicamente se recupera la ya vigente.
    const { data: inv, error: invError } = await db.from("invitaciones")
      .select("id,token_vault_id").eq("registro_id", registro.id)
      .in("estado", ["activa", "emitida"]).order("emitida_at", { ascending: false })
      .limit(1).maybeSingle();
    if (invError) return reply(503, { ok: false, error: "No se pudo consultar la invitación" }, origin);
    if (!inv || !inv.token_vault_id) {
      return reply(409, { ok: false, error: "No hay invitación QR recuperable en Vault" }, origin);
    }

    // RPC existente: descifra desde Vault y comprueba SHA256 del token.
    // p_reemitir=false impide invalidar el QR original.
    const { data: result, error: rpcError } = await db.rpc(rpc, {
      p_registro_id: registro.id, p_admin_id: userId, p_reemitir: false,
    });
    if (rpcError) {
      console.error("No se pudo recuperar QR válido:", rpcError.code ?? "rpc");
      return reply(503, { ok: false, error: "No se pudo recuperar el QR desde Vault" }, origin);
    }
    const payload = result as { invitacion_id?: unknown; token_qr?: unknown; ya_existia?: unknown } | null;
    if (!payload || payload.invitacion_id !== inv.id ||
        payload.ya_existia !== true || typeof payload.token_qr !== "string" ||
        payload.token_qr.length < 16 || payload.token_qr.length > 1024) {
      return reply(409, { ok: false, error: "No se pudo comprobar que el QR sea el vigente" }, origin);
    }

    // El QR codifica exactamente el token que reconoce ControlAcceso.
    const image = await QRCode.toBuffer(payload.token_qr, {
      type: "png",
      width: 900,
      margin: 4,
      errorCorrectionLevel: "H",
      color: { dark: "#000000", light: "#FFFFFFFF" },
    });
    if (image.length < 100 || image.length > 2_000_000 ||
      image[0] !== 0x89 || image[1] !== 0x50 || image[2] !== 0x4e || image[3] !== 0x47) {
      return reply(503, { ok: false, error: "No se pudo formar la imagen PNG" }, origin);
    }

    // Respuesta efímera y privada: no se almacena ni se envía a Meta.
    return new Response(new Uint8Array(image), {
      status: 200,
      headers: {
        ...headers(origin),
        "Content-Type": "image/png",
        "Content-Disposition": 'attachment; filename="qr-amor-' + inv.id + '.png"',
        "Content-Length": String(image.length),
      },
    });
  } catch (e) {
    console.error("QR PNG: excepción", e instanceof Error ? e.name : "desconocida");
    return reply(503, { ok: false, error: "No se pudo generar la imagen QR" }, origin);
  }
});
