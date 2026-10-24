import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';

export const RADEVS = '43e67bda-d19d-4c0e-a639-e85f2d62f294';
export const CHIAPAS = '3dc92160-79af-4bf7-b770-263038e88900';
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
const json = (status: number, error: string) => new Response(
  JSON.stringify({ ok: false, autorizado: false, error, mensaje: error }),
  { status, headers: { ...cors, 'Content-Type': 'application/json' } },
);
type Opciones = { evento?: string; roles: readonly string[]; multipart?: boolean };

/** All private handlers run only after Auth, active profile and active event assignment.
 * The internal header is ALWAYS replaced; client headers never establish authority.
 */
export function serveEvento(opciones: Opciones, handler: (req: Request) => Promise<Response>) {
  Deno.serve(async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (req.method !== 'POST') return json(405, 'Método no permitido');
    try {
      const token = req.headers.get('authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
      if (!token) return json(401, 'Sesión requerida');
      const url = Deno.env.get('SUPABASE_URL');
      const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
      if (!url || !key) return json(503, 'Configuración incompleta');
      const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
      const { data, error } = await db.auth.getUser(token);
      if (error || !data?.user) return json(401, 'Sesión inválida');
      const { data: perfil, error: pe } = await db.from('usuarios')
        .select('rol,activo').eq('id', data.user.id).maybeSingle();
      if (pe) return json(503, 'No se pudo verificar el acceso');
      if (perfil?.activo !== true || !opciones.roles.includes(perfil.rol)) return json(403, 'Sin permiso');
      let solicitado: unknown;
      // Bound the actual stream, including multipart and requests without Content-Length.
      const reader = req.clone().body?.getReader();
      let size = 0;
      const chunks: Uint8Array[] = [];
      const maxBytes = opciones.multipart ? 11 * 1024 * 1024 : 16384;
      if (reader) {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          size += value.byteLength;
          if (size > maxBytes) { void reader.cancel(); return json(413, 'Solicitud demasiado grande'); }
          chunks.push(value);
        }
      }
      if (!opciones.multipart) {
        const bytes = new Uint8Array(size);
        let offset = 0;
        for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
        let body;
        try { body = size ? JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)) : {}; }
        catch { return json(400, 'JSON inválido'); }
        if (!body || typeof body !== 'object' || Array.isArray(body)) return json(400, 'JSON inválido');
        solicitado = body.evento_id;
      }
      const evento = opciones.evento ?? solicitado ?? RADEVS;
      if ((evento !== RADEVS && evento !== CHIAPAS) ||
          (opciones.evento && solicitado !== undefined && solicitado !== opciones.evento)) return json(403, 'Evento no autorizado');
      const { data: asignacion, error: ae } = await db.from('usuarios_eventos')
        .select('usuario_id').eq('usuario_id', data.user.id).eq('evento_id', evento)
        .eq('activo', true).maybeSingle();
      if (ae) return json(503, 'No se pudo verificar la asignación');
      if (!asignacion) return json(403, 'Sin asignación activa para este evento');
      const headers = new Headers(req.headers);
      headers.set('x-evento-autorizado', evento);
      const response = await handler(new Request(req, { headers }));
      response.headers.set('Cache-Control', 'no-store');
      return response;
    } catch {
      return json(500, 'No se pudo completar la operación');
    }
  });
}
