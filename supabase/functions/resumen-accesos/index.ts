import { serveEvento } from "../_shared/evento.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
serveEvento({ roles: ['administrador', 'acceso'] }, async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return respond({ ok: false, error: 'Método no permitido' }, 405);
  try {
    const bearer = req.headers.get('Authorization') || '';
    if (!bearer.startsWith('Bearer ')) return respond({ ok: false, error: 'Sesión requerida' }, 401);
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const auth = createClient(url, anon, { global: { headers: { Authorization: bearer } } });
    const { data: { user }, error: authError } = await auth.auth.getUser();
    if (authError || !user) return respond({ ok: false, error: 'Sesión inválida' }, 401);
    const db = createClient(url, service);
    const { data: perfil, error: perfilError } = await db.from('usuarios').select('rol,activo').eq('id', user.id).single();
    if (perfilError || !perfil?.activo || !['administrador', 'acceso'].includes(perfil.rol)) return respond({ ok: false, error: 'Sin permiso' }, 403);
    const body = await req.json().catch(() => ({}));
    const eventoId = req.headers.get('x-evento-autorizado')!;
    const pagina = Math.max(1, Math.min(100000, Number.isFinite(Number(body.pagina)) ? Math.floor(Number(body.pagina)) : 1));
    const limite = 20;
    const busqueda = String(body.busqueda || '').trim().toLowerCase().slice(0, 100);
    // Los conteos se calculan en servidor y se filtran por rol.
    const [total, confirmados, pendientes, ingresados, pendientesPago] = await Promise.all([
      db.from('registros').select('id', { count: 'exact', head: true }).eq('evento_id', eventoId),
      db.from('registros').select('id', { count: 'exact', head: true }).eq('evento_id', eventoId).eq('estado', 'confirmado'),
      db.from('registros').select('id', { count: 'exact', head: true }).eq('evento_id', eventoId).eq('estado', 'pendiente'),
      db.from('accesos').select('id,invitaciones!inner(registros!inner(evento_id))', { count: 'exact', head: true }).eq('invitaciones.registros.evento_id', eventoId),
      db.from('pagos').select('id,registros!inner(evento_id)', { count: 'exact', head: true }).eq('registros.evento_id', eventoId).in('estado', ['pendiente', 'revision'])
    ]);
    for (const result of [total, confirmados, pendientes, ingresados, pendientesPago]) if (result.error) throw result.error;
    const resumen = { participantes: total.count ?? 0, confirmados: confirmados.count ?? 0, pendientes: pendientes.count ?? 0, pagos_pendientes: pendientesPago.count ?? 0, ingresos: ingresados.count ?? 0 };
    if (body.solo_resumen) return respond({ ok: true, resumen });
    // Leer únicamente el historial reciente; evitar exponer toda la base a roles de acceso.
    const { data: accesos, error: accesosError } = await db.from('accesos')
      .select('id,ingresado_at,operador_id,invitacion_id,invitaciones!inner(registros!inner(evento_id))').eq('invitaciones.registros.evento_id', eventoId)
      .order('ingresado_at', { ascending: false }).limit(1000);
    if (accesosError) throw accesosError;
    const invitacionIds = [...new Set((accesos || []).map(a => a.invitacion_id))];
    const { data: invitaciones, error: invitacionesError } = invitacionIds.length ? await db.from('invitaciones').select('id,registro_id').in('id', invitacionIds) : { data: [], error: null };
    if (invitacionesError) throw invitacionesError;
    const registroIds = [...new Set((invitaciones || []).map(i => i.registro_id))];
    const { data: registros, error: registrosError } = registroIds.length ? await db.from('registros').select('id,folio,promotora_id,asesor_id').in('id', registroIds).eq('evento_id', eventoId) : { data: [], error: null };
    if (registrosError) throw registrosError;
    const promotoraIds = [...new Set((registros || []).map(r => r.promotora_id))];
    const asesorIds = [...new Set((registros || []).map(r => r.asesor_id).filter(Boolean))];
    const operadorIds = [...new Set((accesos || []).map(a => a.operador_id))];
    const [promotorasResult, asesoresResult, operadoresResult] = await Promise.all([
      promotoraIds.length ? db.from('promotoras').select('id,nombres,apellidos,foto_path').in('id', promotoraIds) : Promise.resolve({ data: [], error: null }),
      asesorIds.length ? db.from('asesores').select('id,nombre').in('id', asesorIds) : Promise.resolve({ data: [], error: null }),
      operadorIds.length ? db.from('usuarios').select('id,nombre').in('id', operadorIds) : Promise.resolve({ data: [], error: null })
    ]);
    for (const result of [promotorasResult, asesoresResult, operadoresResult]) if (result.error) throw result.error;
    const byId = <T extends { id: string }>(rows: T[]) => new Map(rows.map(r => [r.id, r]));
    const invitacionMap = byId(invitaciones || []), registroMap = byId(registros || []), promotoraMap = byId(promotorasResult.data || []), asesorMap = byId(asesoresResult.data || []), operadorMap = byId(operadoresResult.data || []);
    const lista = (accesos || []).filter(a => { const i = invitacionMap.get(a.invitacion_id); return i && registroMap.has(i.registro_id); }).map(a => {
      const i = invitacionMap.get(a.invitacion_id);
      const r = i && registroMap.get(i.registro_id);
      const p = r && promotoraMap.get(r.promotora_id);
      return { id: a.id, ingresado_at: a.ingresado_at, folio: r?.folio || '', nombre: [p?.nombres, p?.apellidos].filter(Boolean).join(' ') || 'Sin nombre', asesor: r?.asesor_id ? asesorMap.get(r.asesor_id)?.nombre || '' : '', operador: operadorMap.get(a.operador_id)?.nombre || 'Operador', foto_path: p?.foto_path || null };
    }).filter(a => !busqueda || `${a.nombre} ${a.folio} ${a.asesor} ${a.operador}`.toLowerCase().includes(busqueda));
    const desde = (pagina - 1) * limite;
    const paginaRows = lista.slice(desde, desde + limite);
    const bucket = Deno.env.get('FOTO_BUCKET');
    const ingresos = await Promise.all(paginaRows.map(async ({ foto_path, ...a }) => {
      let foto_url: string | null = null;
      if (bucket && foto_path) { const { data } = await db.storage.from(bucket).createSignedUrl(foto_path, 120); foto_url = data?.signedUrl || null; }
      return { ...a, foto_url };
    }));
    return respond({ ok: true, resumen, ingresos, total_historial: lista.length, pagina, limite, historial_limitado: (accesos || []).length === 1000 });
  } catch { return respond({ ok: false, error: 'No se pudo consultar el resumen' }, 500); }
});
