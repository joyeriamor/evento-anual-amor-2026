import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const ALLOWED_ORIGINS = new Set([
  "https://joyeriamor.github.io",
  "http://localhost:5173",
]);
const TEMPLATE = "amor_invitacion_confirmada_v1";
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

    const { data: registro, error: registroError } = await db.from("registros")
      .select("id,evento_id,promotora_id,estado,es_prueba,exento_pago")
      .eq("id", body.registro_id).maybeSingle();
    if (registroError) return response(503, { ok: false, error: "No se pudo consultar el registro" }, origin);
    if (!registro) return response(404, { ok: false, error: "Registro inexistente" }, origin);

    const { data: permiso, error: permisoError } = await db.from("usuarios_eventos")
      .select("evento_id").eq("usuario_id", identity.user.id)
      .eq("evento_id", registro.evento_id).eq("activo", true).maybeSingle();
    if (permisoError) return response(503, { ok: false, error: "No se pudo verificar la asignación al evento" }, origin);
    if (!permiso) return response(403, { ok: false, error: "Sin permisos para este evento" }, origin);

    if (registro.estado !== "confirmado" || registro.es_prueba === true) {
      return response(409, { ok: false, error: "La inscripción no es real y confirmada" }, origin);
    }
    if (!registro.exento_pago) {
      const { data: pago, error: pagoError } = await db.from("pagos")
        .select("id").eq("registro_id", registro.id).eq("estado", "validado").maybeSingle();
      if (pagoError) return response(503, { ok: false, error: "No se pudo verificar el pago" }, origin);
      if (!pago) return response(409, { ok: false, error: "No hay pago validado ni cortesía autorizada" }, origin);
    }

    const { data: invitacion, error: invError } = await db.from("invitaciones")
      .select("id,estado").eq("registro_id", registro.id)
      .in("estado", ["activa", "emitida"])
      .order("emitida_at", { ascending: false })
      .limit(1).maybeSingle();
    if (invError) return response(503, { ok: false, error: "No se pudo consultar la invitación" }, origin);
    if (!invitacion) return response(409, { ok: false, error: "Todavía no existe una invitación QR válida" }, origin);

    const { data: promotora, error: promError } = await db.from("promotoras")
      .select("telefono_whatsapp").eq("id", registro.promotora_id).maybeSingle();
    if (promError) return response(503, { ok: false, error: "No se pudo verificar el contacto" }, origin);
    if (!promotora?.telefono_whatsapp || !/[0-9]{10,}/.test(promotora.telefono_whatsapp.replace(/[^\d]/g, ""))) {
      return response(409, { ok: false, error: "El registro no tiene un WhatsApp de contacto completo" }, origin);
    }

    // Consentimiento por WhatsApp separado del aviso de privacidad.
    // La ausencia de fila no significa consentimiento tácito.
    const { data: consentimiento, error: consentimientoError } = await db
      .from("whatsapp_consentimientos_invitacion")
      .select("aceptado_at,retirado_at,origen")
      .eq("registro_id", registro.id).maybeSingle();
    if (consentimientoError) {
      return response(503, { ok: false, error: "No se pudo verificar el consentimiento para WhatsApp" }, origin);
    }
    const consentimientoVigente =
      Boolean(consentimiento?.aceptado_at && !consentimiento?.retirado_at);

    if (body.preparar === true && consentimientoVigente) {
      const { error: insertError } = await db.rpc("whatsapp_encolar_interno", {p_invitacion_id: invitacion.id});
      if (insertError) return response(503, {ok:false,error:"No fue posible preparar la notificación"}, origin);
    }

    const { data: envio, error: envioError } = await db.from("whatsapp_envios_invitacion")
      .select("id,estado,consentimiento_confirmado_at,created_at")
      .eq("invitacion_id", invitacion.id).eq("plantilla", TEMPLATE).maybeSingle();
    if (envioError) return response(503, { ok: false, error: "No fue posible consultar la bitácora" }, origin);

    return response(200, {
      ok: true,
      modo: body.preparar === true ? "preparado_sin_envio" : "solo_consulta",
      registro_id: registro.id,
      evento_id: registro.evento_id,
      tipo: registro.exento_pago ? "cortesia" : "pago_validado",
      invitacion_id: invitacion.id,
      plantilla: TEMPLATE,
      estado_whatsapp: envio?.estado ?? "no_preparado",
      consentimiento_registrado: consentimientoVigente,
      consentimiento_estado: !consentimiento ? "no_registrado" : consentimiento.retirado_at ? "retirado" : "vigente",
      entrega_automatica_habilitada: false,
      nota: "Esta función no llama a Meta, no lee tokens QR y no envía mensajes.",
    }, origin);
  } catch (error) {
    console.error("whatsapp-preparar:", error instanceof Error ? error.name : "error");
    return response(503, { ok: false, error: "No fue posible completar la revisión" }, origin);
  }
});
