import { serveEvento } from "../_shared/evento.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';

// Consulta del cupo exclusivamente para administradores activos.
const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};

function responder(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

serveEvento({ roles: ['administrador'] }, async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return responder(405, { ok: false, error: 'Método no permitido' });

  const token = req.headers.get('authorization')?.match(/^Bearer\s+([^\s]+)$/i)?.[1];
  if (!token) return responder(401, { ok: false, error: 'Inicia sesión como administrador' });

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) return responder(503, { ok: false, error: 'Configuración del servidor incompleta' });
  const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  try {
    const { data: identidad, error: authError } = await db.auth.getUser(token);
    if (authError || !identidad.user) return responder(401, { ok: false, error: 'Sesión caducada o inválida' });

    const { data: perfil, error: perfilError } = await db.from('usuarios')
      .select('rol,activo').eq('id', identidad.user.id).maybeSingle();
    if (perfilError) return responder(503, { ok: false, error: 'No se pudo comprobar el rol' });
    if (perfil?.rol !== 'administrador' || perfil?.activo !== true) {
      return responder(403, { ok: false, error: 'Se requiere una cuenta administradora activa' });
    }

    const { data: cupo, error: cupoError } = await db.rpc('resumen_cupo_evento_interno', {
      p_evento_id: req.headers.get('x-evento-autorizado')!,
    });
    if (cupoError || !cupo) {
      console.error('No se pudo consultar el cupo', cupoError?.message);
      return responder(500, { ok: false, error: 'No se pudo consultar el cupo del evento' });
    }
    return responder(200, { ok: true, cupo });
  } catch (error) {
    console.error('Error en resumen-cupo-evento', error instanceof Error ? error.message : 'desconocido');
    return responder(500, { ok: false, error: 'Error consultando el cupo' });
  }
});
