import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (v: unknown, status = 200) => new Response(JSON.stringify(v), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});
const LIMITE = 20;
const MAX_CONSULTA = 500;
const EVENTO_CHIAPAS_ID = '3dc92160-79af-4bf7-b770-263038e88900';

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json({ ok: false, error: 'Método no permitido' }, 405);
  try {
    const bearer = req.headers.get('Authorization') || '';
    const token = bearer.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return json({ ok: false, error: 'Inicia sesión' }, 401);
    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anon || !service) return json({ ok: false, error: 'Configuración incompleta' }, 500);
    const auth = createClient(url, anon);
    const { data: { user }, error: loginError } = await auth.auth.getUser(token);
    if (loginError || !user) return json({ ok: false, error: 'Sesión inválida' }, 401);
    const db = createClient(url, service);
    const { data: perfil, error: perfilError } = await db.from('usuarios')
      .select('rol,activo').eq('id', user.id).maybeSingle();
    if (perfilError) throw perfilError;
    if (!perfil?.activo || !['administrador','validador','recepcion'].includes(perfil.rol)) {
      return json({ ok: false, error: 'Sin permiso' }, 403);
    }
    // Verificar asignacion antes de consultar datos privados.
    const { data: asignacion, error: errorAsignacion } =
      await db.from('usuarios_eventos')
        .select('usuario_id')
        .eq('usuario_id', user.id)
        .eq('evento_id', EVENTO_CHIAPAS_ID)
        .eq('activo', true)
        .maybeSingle();

    if (errorAsignacion) {
      console.error('Error verificando acceso Chiapas:', errorAsignacion.message);
      return json({ ok: false, error: 'No se pudo verificar el acceso' }, 500);
    }

    if (!asignacion) {
      return json({ ok: false, error: 'Sin acceso a Chiapas' }, 403);
    }

    const body = await req.json().catch(() => ({}));
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return json({ ok: false, error: 'JSON invalido' }, 400);
    }

    if (
      body.evento_id !== undefined &&
      body.evento_id !== EVENTO_CHIAPAS_ID
    ) {
      return json({ ok: false, error: 'Evento no autorizado' }, 403);
    }
    const tipo = body.tipo === 'pagos' ? 'pagos' : body.tipo === 'participantes' ? 'participantes' : null;
    if (!tipo) return json({ ok: false, error: 'Tipo inválido' }, 400);
    if ((tipo === 'pagos' && !['administrador','validador'].includes(perfil.rol)) ||
        (tipo === 'participantes' && !['administrador','recepcion'].includes(perfil.rol))) {
      return json({ ok: false, error: 'Tu rol no tiene permiso para esta consulta' }, 403);
    }
    const pagina = Math.max(1, Math.min(1000, Math.floor(Number(body.pagina) || 1)));
    const busqueda = String(body.busqueda || '').trim().toLocaleLowerCase('es').slice(0, 100);
    type Base = { id: string; registro_id: string; estado: string; importe?: number | null; referencia?: string | null; comprobante_path?: string | null; created_at: string };
    let bases: Base[] = [];
    let registros: Array<{id:string;folio:string|null;estado:string;promotora_id:string|null;created_at:string;exento_pago:boolean}> = [];
    if (tipo === 'pagos') {
      const { data, error } = await db.from('pagos')
        .select('id,registro_id,estado,importe,referencia,comprobante_path,created_at,registros!inner(evento_id)').eq('registros.evento_id', EVENTO_CHIAPAS_ID)
        .in('estado', ['pendiente','revision']).order('created_at', { ascending: false }).limit(MAX_CONSULTA);
      if (error) throw error;
      bases = data || [];
      const ids = [...new Set(bases.map(p => p.registro_id))];
      if (ids.length) {
        const { data: rs, error: re } = await db.from('registros')
          .select('id,folio,estado,promotora_id,created_at,exento_pago').in('id', ids).eq('evento_id', EVENTO_CHIAPAS_ID);
        if (re) throw re;
        registros = rs || [];
      }
    } else {
      const { data, error } = await db.from('registros')
        .select('id,folio,estado,promotora_id,created_at,exento_pago').eq('evento_id', EVENTO_CHIAPAS_ID)
        .order('created_at', { ascending: false }).limit(MAX_CONSULTA);
      if (error) throw error;
      registros = data || [];
    }
    const promIds = [...new Set(registros.map(r => r.promotora_id).filter((id): id is string => Boolean(id)))];
    const { data: promotoras, error: pe } = promIds.length
      ? await db.from('promotoras').select('id,nombres,apellidos,telefono_whatsapp').in('id', promIds)
      : { data: [], error: null };
    if (pe) throw pe;
    const pm = new Map((promotoras || []).map(p => [p.id, p]));
    const registroPorId = new Map(registros.map(r => [r.id, r]));
    const fila = (r: typeof registros[number]) => {
      const p = r.promotora_id ? pm.get(r.promotora_id) : null;
      return {
        registro_id: r.id,
        folio: r.folio || '—',
        nombre: [p?.nombres, p?.apellidos].filter(Boolean).join(' ') || 'Sin nombre',
        telefono: p?.telefono_whatsapp || '',
        registro_estado: r.estado,
        exento_pago: r.exento_pago,
        fecha: r.created_at,
      };
    };
    let filas = tipo === 'pagos'
      ? bases.flatMap(p => {
          const r = registroPorId.get(p.registro_id);
          return r ? [{ ...fila(r), pago_id: p.id, pago_estado: p.estado, importe: p.importe,
                        referencia: p.referencia, comprobante_path: p.comprobante_path, fecha: p.created_at }] : [];
        })
      : registros.map(r => ({ ...fila(r), pago_id: null, pago_estado: null,
                                importe: null, referencia: null, comprobante_path: null }));
    if (busqueda) filas = filas.filter(f => `${f.nombre} ${f.folio} ${f.telefono}`.toLocaleLowerCase('es').includes(busqueda));
    const total = filas.length;
    const paginaFilas = filas.slice((pagina - 1) * LIMITE, pagina * LIMITE);
    const resultado = await Promise.all(paginaFilas.map(async f => {
      if (tipo !== 'pagos' || !f.comprobante_path) return { ...f, comprobante_url: null, comprobante_path: undefined };
      const { data } = await db.storage.from('comprobantes-pago').createSignedUrl(f.comprobante_path, 60);
      return { ...f, comprobante_url: data?.signedUrl || null, comprobante_path: undefined };
    }));
    return json({ ok: true, registros: resultado, pagina, limite: LIMITE, total, limitado: bases.length === MAX_CONSULTA || registros.length === MAX_CONSULTA });
  } catch (e) {
    console.error('bandeja-personal:', e instanceof Error ? e.message : String(e));
    return json({ ok: false, error: 'No se pudo consultar la información' }, 500);
  }
});
