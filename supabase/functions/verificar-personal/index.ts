import { serveEvento } from "../_shared/evento.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';

// Esta función se despliega con verificación JWT habilitada (no usar --no-verify-jwt).
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
const responder = (datos: unknown, status = 200) => new Response(JSON.stringify(datos), {
  status,
  headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
});
const rolesValidos = new Set(['administrador', 'validador', 'recepcion', 'acceso']);

serveEvento({ roles: ['administrador', 'validador', 'recepcion', 'acceso'] }, async req => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return responder({ ok: false, error: 'Método no permitido' }, 405);

  try {
    const token = req.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return responder({ ok: false, autorizado: false, error: 'Sesión requerida' }, 401);

    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anon || !service) {
      console.error('Faltan variables de entorno de Supabase en verificar-personal');
      return responder({ ok: false, autorizado: false, error: 'Configuración incompleta' }, 500);
    }

    // Verificar la identidad contra Auth. El JWT de la cabecera no basta sin validación.
    const auth = createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: { user }, error: errorSesion } = await auth.auth.getUser(token);
    if (errorSesion || !user) {
      return responder({ ok: false, autorizado: false, error: 'Sesión inválida o expirada' }, 401);
    }

    // La lectura de usuarios se hace SOLO en el servidor para evitar bloqueos por RLS.
    const db = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: perfil, error: errorPerfil } = await db.from('usuarios')
      .select('nombre,rol,activo')
      .eq('id', user.id)
      .maybeSingle();
    if (errorPerfil) throw errorPerfil;

    if (!perfil) return responder({ ok: true, autorizado: false, error: 'No existe el perfil de este usuario en la tabla usuarios.' }, 403);
    if (perfil.activo !== true) return responder({ ok: true, autorizado: false, error: 'La cuenta está desactivada. Solicita al administrador que la active.' }, 403);
    if (!rolesValidos.has(perfil.rol)) return responder({ ok: true, autorizado: false, error: 'La cuenta no tiene un rol válido.' }, 403);

    return responder({
      ok: true,
      autorizado: true,
      evento_id: req.headers.get('x-evento-autorizado'),
      usuario: { id: user.id, nombre: perfil.nombre ?? '', rol: perfil.rol },
    });
  } catch (e) {
    console.error('verificar-personal:', e instanceof Error ? e.message : String(e));
    return responder({ ok: false, autorizado: false, error: 'No se pudo verificar la sesión' }, 500);
  }
});
