import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';

// Función de login pública: desplegar con --no-verify-jwt porque
// todavía NO existe una sesión cuando el empleado ingresa.
// Nunca entrega el correo interno ni la service_role al navegador.
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
const respond = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
  });
const invalid = () => respond({ ok: false, error: 'Usuario o contraseña incorrectos.' }, 401);
const patron = /^[a-z][a-z0-9._-]{2,31}$/;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return respond({ ok: false, error: 'Método no permitido.' }, 405);
  try {
    // Limitar el cuerpo del login a 4 KB reales.
    const MAX_LOGIN_BODY_BYTES = 4096;

    const longitudDeclarada = req.headers.get('content-length');

    if (
      longitudDeclarada !== null &&
      (
        !/^\d+$/.test(longitudDeclarada) ||
        Number(longitudDeclarada) > MAX_LOGIN_BODY_BYTES
      )
    ) {
      return respond({ ok: false, error: 'Solicitud demasiado grande.' }, 413);
    }

    const lector = req.body?.getReader();
    if (!lector) return invalid();

    let bytesRecibidos = 0;
    let textoJson = '';
    const decodificador = new TextDecoder('utf-8', { fatal: true });

    while (true) {
      const { done, value } = await lector.read();
      if (done) break;

      bytesRecibidos += value.byteLength;

      if (bytesRecibidos > MAX_LOGIN_BODY_BYTES) {
        await lector.cancel();
        return respond({
          ok: false,
          error: 'Solicitud demasiado grande.'
        }, 413);
      }

      textoJson += decodificador.decode(value, { stream: true });
    }

    let datos: { usuario?: unknown; password?: unknown; evento_id?: unknown } | null = null;

    try {
      textoJson += decodificador.decode();

      const objeto = JSON.parse(textoJson);

      if (
        objeto !== null &&
        typeof objeto === 'object' &&
        !Array.isArray(objeto)
      ) {
        datos = objeto;
      }
    } catch {
      return invalid();
    }
    const nombreUsuario = typeof datos?.usuario === 'string' ? datos.usuario.trim().toLowerCase() : '';
    const password = typeof datos?.password === 'string' ? datos.password : '';
    if (!patron.test(nombreUsuario) || !password || password.length > 256) return invalid();

    // Límite de 20 solicitudes por usuario cada 15 minutos.
    // Se ejecuta antes de consultar la tabla usuarios.
    const secretoLimite = Deno.env.get('LOGIN_RATE_LIMIT_SECRET');

    if (!secretoLimite) {
      return respond({
        ok: false,
        error: 'Protección de acceso no disponible.'
      }, 503);
    }

    const llave = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secretoLimite),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    const firma = await crypto.subtle.sign(
      'HMAC',
      llave,
      new TextEncoder().encode(`login-usuario:${nombreUsuario}`)
    );

    const hashUsuario = Array.from(new Uint8Array(firma))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    const urlLimite = Deno.env.get('SUPABASE_URL');
    const serviceLimite = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!urlLimite || !serviceLimite) {
      return respond({
        ok: false,
        error: 'Configuración incompleta.'
      }, 503);
    }

    const dbLimite = createClient(urlLimite, serviceLimite, {
      auth: { persistSession: false, autoRefreshToken: false }
    });

    const { data: permitido, error: errorLimite } =
      await dbLimite.rpc('comprobar_limite_login', {
        p_clave_hash: hashUsuario
      });

    if (errorLimite) {
      console.error('Error en limitador:', errorLimite.message);
      return respond({
        ok: false,
        error: 'Acceso temporalmente no disponible.'
      }, 503);
    }

    if (permitido !== true) {
      return respond({
        ok: false,
        error: 'Demasiados intentos. Intenta nuevamente en 15 minutos.'
      }, 429);
    }
    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anon || !service) return respond({ ok: false, error: 'No se ha configurado la autenticación.' }, 500);

    const db = createClient(url, service, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: perfil, error: perfilError } = await db.from('usuarios')
      .select('id,rol,activo').eq('nombre_usuario', nombreUsuario).maybeSingle();
    if (perfilError) throw perfilError;
    if (!perfil?.activo) return invalid();
    if (!['administrador', 'validador', 'recepcion', 'acceso'].includes(perfil.rol)) return invalid();

    const { data: authData, error: readError } = await db.auth.admin.getUserById(perfil.id);
    if (readError || !authData?.user?.email) return invalid();

    // No se comprueba ni almacena la contraseña aquí. GoTrue/Supabase Auth
    // verifica el hash, aplica sus políticas de contraseñas y límites de intentos.
    const clienteAuth = createClient(url, anon, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: sesion, error: authError } = await clienteAuth.auth.signInWithPassword({
      email: authData.user.email,
      password,
    });
    if (authError || !sesion.session || sesion.user?.id !== perfil.id) return invalid();

    const eventoId = datos?.evento_id ?? '43e67bda-d19d-4c0e-a639-e85f2d62f294';
    if (!['43e67bda-d19d-4c0e-a639-e85f2d62f294','3dc92160-79af-4bf7-b770-263038e88900'].includes(String(eventoId))) return invalid();
    const { data: asignacion, error: errorAsignacion } = await db.from('usuarios_eventos')
      .select('usuario_id').eq('usuario_id', sesion.user.id).eq('evento_id', eventoId)
      .eq('activo', true).maybeSingle();
    if (errorAsignacion || !asignacion) return invalid();

    return respond({
      ok: true,
      access_token: sesion.session.access_token,
      refresh_token: sesion.session.refresh_token,
    });
  } catch (e) {
    console.error('Error autenticando usuario:', e instanceof Error ? e.message : String(e));
    return respond({ ok: false, error: 'No fue posible iniciar sesión. Inténtalo de nuevo.' }, 500);
  }
});
