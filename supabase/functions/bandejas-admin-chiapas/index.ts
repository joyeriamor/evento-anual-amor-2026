import { serveEvento, CHIAPAS } from "../_shared/evento.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

serveEvento({ roles: ['administrador'], evento: CHIAPAS }, async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }
  if (req.method !== 'POST') {
    return json({ ok: false, error: 'Método no permitido' }, 405);
  }

  try {
    const bearer = req.headers.get('Authorization') || '';
    if (!/^Bearer\s+\S+$/i.test(bearer)) {
      return json({ ok: false, error: 'Sesión requerida' }, 401);
    }

    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anon || !service) {
      return json({ ok: false, error: 'Configuración incompleta' }, 500);
    }

    // Identidad obtenida de Supabase Auth; nunca del JSON del usuario.
    const auth = createClient(url, anon, {
      global: { headers: { Authorization: bearer } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await auth.auth.getUser();
    if (authError || !user) {
      return json({ ok: false, error: 'Sesión inválida' }, 401);
    }

    const db = createClient(url, service, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: perfil, error: perfilError } = await db
      .from('usuarios')
      .select('rol,activo')
      .eq('id', user.id)
      .maybeSingle();

    if (perfilError) throw perfilError;
    if (perfil?.activo !== true || perfil.rol !== 'administrador') {
      return json({ ok: false, error: 'Sin permiso' }, 403);
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return json({ ok: false, error: 'JSON inválido' }, 400);
    }

    const tipo = body.tipo === 'pagos'
      ? 'pagos'
      : body.tipo === 'invitaciones'
      ? 'invitaciones'
      : null;
    if (!tipo) return json({ ok: false, error: 'Tipo inválido' }, 400);

    const rawPagina = Number(body.pagina);
    const pagina = Number.isFinite(rawPagina)
      ? Math.max(1, Math.min(10000, Math.floor(rawPagina)))
      : 1;
    const busqueda = String(body.busqueda ?? '').trim().slice(0, 100);
    const limite = 20;

    // Filtrado + conteo + paginado dentro de PostgreSQL, sin tope de 1000 filas.
    // El evento es fijo en el servidor; no depende del navegador.
    const eventoChiapasId =
      '3dc92160-79af-4bf7-b770-263038e88900';

    if (
      body.evento_id !== undefined &&
      body.evento_id !== eventoChiapasId
    ) {
      return json(
        { ok: false, error: 'Evento no autorizado' },
        403
      );
    }

    // La consulta usa service_role, pero solamente despues
    // de verificar la sesion y el rol administrativo.
    const { data: asignacionChiapas, error: errorAsignacionChiapas } =
      await db.from('usuarios_eventos')
        .select('usuario_id')
        .eq('usuario_id', user.id)
        .eq('evento_id', eventoChiapasId)
        .eq('activo', true)
        .maybeSingle();

    if (errorAsignacionChiapas) {
      console.error(
        'Error verificando asignacion Chiapas:',
        errorAsignacionChiapas.message
      );

      return json(
        { ok: false, error: 'No se pudo verificar el acceso' },
        500
      );
    }

    if (!asignacionChiapas) {
      return json(
        { ok: false, error: 'Sin acceso a Chiapas' },
        403
      );
    }

    const { data, error } = await db.rpc('bandejas_admin_chiapas_paginadas', {
      p_tipo: tipo,
      p_pagina: pagina,
      p_busqueda: busqueda,
      p_admin_id: user.id,
    });
    if (error) throw error;

    // Mantener intacta la respuesta que ya consume el panel.
    const total = typeof data?.total === 'number' ? data.total : Number(data?.total ?? 0);
    const registros = Array.isArray(data?.registros) ? data.registros : [];
    return json({
      ok: true,
      tipo,
      total,
      pagina,
      limite,
      registros,
      limitado: false,
    });
  } catch (e) {
    console.error('Error en bandejas-admin:', e instanceof Error ? e.message : String(e));
    return json({ ok: false, error: 'No se pudo cargar la bandeja.' }, 500);
  }
});
