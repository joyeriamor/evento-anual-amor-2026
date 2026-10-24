import { serveEvento } from "../_shared/evento.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
const respond = (payload: unknown, status = 200) => new Response(JSON.stringify(payload), {
  status, headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
});
const roles = new Set(['administrador', 'validador', 'recepcion', 'acceso']);
const patronUsuario = /^[a-z][a-z0-9._-]{2,31}$/;
const patronUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const normalizarUsuario = (value: unknown) => typeof value === 'string' ? value.trim().toLowerCase() : '';
const validaPassword = (value: unknown): value is string => typeof value === 'string' && value.length >= 10 && value.length <= 128 && /\p{L}/u.test(value) && /\d/u.test(value);

serveEvento({ roles: ['administrador'] }, async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return respond({ ok: false, error: 'Método no permitido' }, 405);
  try {
    const token = (req.headers.get('Authorization') || '').match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return respond({ ok: false, error: 'Inicia sesión.' }, 401);
    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anon || !service) return respond({ ok: false, error: 'Configuración incompleta' }, 500);

    const clientePublico = createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: { user }, error: authError } = await clientePublico.auth.getUser(token);
    if (authError || !user) return respond({ ok: false, error: 'Sesión inválida' }, 401);

    const db = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: administrador, error: perfilError } = await db.from('usuarios')
      .select('rol,activo').eq('id', user.id).maybeSingle();
    if (perfilError) throw perfilError;
    if (administrador?.activo !== true || administrador.rol !== 'administrador')
      return respond({ ok: false, error: 'No tienes permisos de administrador' }, 403);

    // Máximo 4 KB para operaciones de administración.
    const MAX_GESTION_BYTES = 4096;

    const lector = req.body?.getReader();
    if (!lector) {
      return respond({ ok: false, error: 'Solicitud vacía.' }, 400);
    }

    let total = 0;
    const partes: Uint8Array[] = [];

    while (true) {
      const { done, value } = await lector.read();
      if (done) break;

      total += value.byteLength;

      if (total > MAX_GESTION_BYTES) {
        await lector.cancel();
        return respond({
          ok: false,
          error: 'Solicitud demasiado grande.'
        }, 413);
      }

      partes.push(value);
    }

    const buffer = new Uint8Array(total);
    let posicion = 0;

    for (const parte of partes) {
      buffer.set(parte, posicion);
      posicion += parte.byteLength;
    }

    let body: Record<string, unknown>;

    try {
      body = JSON.parse(
        new TextDecoder('utf-8', { fatal: true }).decode(buffer)
      );
    } catch {
      return respond({ ok: false, error: 'JSON inválido.' }, 400);
    }

    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return respond({ ok: false, error: 'Solicitud inválida.' }, 400);
    }
    const accion = String(body?.accion || '');
    const eventoId = req.headers.get('x-evento-autorizado')!;
    const { data: miembros, error: miembrosError } = await db.from('usuarios_eventos')
      .select('usuario_id').eq('evento_id', eventoId).eq('activo', true);
    if (miembrosError) throw miembrosError;
    const idsMiembros = (miembros || []).map(m => m.usuario_id);
    if (accion === 'actualizar') {
      if (!idsMiembros.includes(body.id)) return respond({ ok: false, error: 'Usuario no encontrado' }, 404);
      const { data: compartido, error: ce } = await db.from('usuarios_eventos')
        .select('usuario_id').eq('usuario_id', body.id).neq('evento_id', eventoId).eq('activo', true).limit(1);
      if (ce) throw ce;
      if (compartido?.length) return respond({ ok: false, error: 'Esta cuenta opera en varios eventos. No se permite modificar su perfil global desde un solo evento.' }, 409);
    }

    const auditar = async (nombreAccion: string, id: string, detalles: Record<string, unknown>) => {
      const { error } = await db.from('auditoria').insert({
        usuario_id: user.id, accion: nombreAccion, entidad: 'usuarios', entidad_id: id, detalles,
      });
      if (error) console.error('No se pudo guardar auditoría:', error.message);
    };

    if (accion === 'listar') {
      const { data: usuarios, error } = await db.from('usuarios')
        .select('id,nombre,nombre_usuario,rol,activo,created_at').in('id', idsMiembros)
        .order('created_at', { ascending: false }).limit(1000);
      if (error) throw error;
      return respond({ ok: true, usuarios: usuarios || [] });
    }

    if (accion === 'crear') {
      const nombre = String(body.nombre || '').trim();
      const nombreUsuario = normalizarUsuario(body.nombre_usuario);
      const rol = String(body.rol || '');
      const password = body.password;
      if (nombre.length < 2 || nombre.length > 120 || !patronUsuario.test(nombreUsuario) || !roles.has(rol))
        return respond({ ok: false, error: 'Verifica el nombre, usuario (3 a 32 caracteres) y rol.' }, 400);
      if (!validaPassword(password))
        return respond({ ok: false, error: 'La contraseña debe tener al menos 10 caracteres, una letra y un número.' }, 400);

      const { data: duplicado, error: checkError } = await db.from('usuarios')
        .select('id').eq('nombre_usuario', nombreUsuario).maybeSingle();
      if (checkError) throw checkError;
      if (duplicado) return respond({ ok: false, error: 'Ese nombre de usuario ya existe.' }, 409);

      // Supabase Auth requiere correo de forma interna. Usamos un identificador
      // aleatorio no entregable en dominio reservado example.com. Nunca se solicita
      // ni se muestra correo al empleado. La contraseña solo llega a Supabase Auth.
      const emailInterno = `empleado-${crypto.randomUUID()}@usuarios.example.com`;
      const { data: creado, error: createError } = await db.auth.admin.createUser({
        email: emailInterno, password, email_confirm: true,
        user_metadata: { nombre },
      });
      if (createError || !creado.user) return respond({ ok: false, error: 'No se pudo crear el usuario.' }, 400);
      const { error: insertError } = await db.rpc('crear_perfil_evento_interno', {
        p_admin_id: user.id, p_evento_id: eventoId, p_usuario_id: creado.user.id,
        p_nombre: nombre, p_nombre_usuario: nombreUsuario, p_rol: rol,
      });
      if (insertError) {
        const { error: deleteError } = await db.auth.admin.deleteUser(creado.user.id);
        if (deleteError) console.error('No se pudo revertir creación Auth:', deleteError.message);
        return respond({ ok: false, error: insertError.code === '23505' ? 'Ese usuario ya existe.' : 'No se pudo crear el perfil y su asignación.' }, 400);
      }
      return respond({ ok: true, id: creado.user.id });
    }

    if (accion === 'actualizar') {
      const id = String(body.id || '');
      if (!patronUUID.test(id)) return respond({ ok: false, error: 'ID inválido.' }, 400);
      const { data: actual, error: readError } = await db.from('usuarios')
        .select('id,nombre,nombre_usuario,rol,activo').eq('id', id).maybeSingle();
      if (readError) throw readError;
      if (!actual) return respond({ ok: false, error: 'Usuario inexistente.' }, 404);

      const cambios: Record<string, unknown> = {};
      if (Object.prototype.hasOwnProperty.call(body, 'nombre')) {
        const nombre = String(body.nombre || '').trim();
        if (nombre.length < 2 || nombre.length > 120) return respond({ ok: false, error: 'Nombre inválido.' }, 400);
        cambios.nombre = nombre;
      }
      if (Object.prototype.hasOwnProperty.call(body, 'nombre_usuario')) {
        const nombreUsuario = normalizarUsuario(body.nombre_usuario);
        if (!patronUsuario.test(nombreUsuario)) return respond({ ok: false, error: 'El usuario debe tener 3 a 32 caracteres, comenzar con letra y usar letras, números, puntos, guiones o guion bajo.' }, 400);
        cambios.nombre_usuario = nombreUsuario;
      }
      if (Object.prototype.hasOwnProperty.call(body, 'rol')) {
        if ((typeof body.rol !== 'string' || !roles.has(body.rol))) return respond({ ok: false, error: 'Rol inválido.' }, 400);
        cambios.rol = body.rol;
      }
      if (Object.prototype.hasOwnProperty.call(body, 'activo')) {
        if (typeof body.activo !== 'boolean') return respond({ ok: false, error: 'Estado inválido.' }, 400);
        cambios.activo = body.activo;
      }
      const passwordNuevo = body.password;
      const cambiandoPassword = typeof passwordNuevo === 'string' && passwordNuevo.length > 0;
      if (cambiandoPassword && !validaPassword(passwordNuevo)) return respond({ ok: false, error: 'La contraseña debe tener al menos 10 caracteres, una letra y un número.' }, 400);

      // El administrador puede asignarse nombre de usuario y cambiarse su
      // contraseña, pero NO elevar/desactivar su propio rol ni su propio estado.
      if (id === user.id &&
        (('rol' in cambios && cambios.rol !== actual.rol) ||
         ('activo' in cambios && cambios.activo !== actual.activo)))
        return respond({ ok: false, error: 'No puedes cambiar tu propio rol ni desactivar tu cuenta.' }, 400);
      if (actual.rol === 'administrador' && actual.activo &&
        (('rol' in cambios && cambios.rol !== 'administrador') || cambios.activo === false)) {
        const { count, error: countError } = await db.from('usuarios')
          .select('id', { count: 'exact', head: true }).in('id', idsMiembros).eq('rol', 'administrador').eq('activo', true);
        if (countError) throw countError;
        if ((count ?? 0) <= 1) return respond({ ok: false, error: 'No puedes desactivar al último administrador.' }, 400);
      }

      if ('nombre_usuario' in cambios && cambios.nombre_usuario !== actual.nombre_usuario) {
        const { data: duplicado, error } = await db.from('usuarios')
          .select('id').eq('nombre_usuario', cambios.nombre_usuario).neq('id', id).maybeSingle();
        if (error) throw error;
        if (duplicado) return respond({ ok: false, error: 'Ese nombre de usuario ya existe.' }, 409);
      }
      if (!Object.keys(cambios).length && !cambiandoPassword) return respond({ ok: false, error: 'No hay cambios.' }, 400);

      // Conservar la fila de perfil antes de cambiar credenciales; si Auth falla,
      // revertimos los campos de perfil en la medida de lo posible.
      if (Object.keys(cambios).length) {
        const { error: updateError } = await db.from('usuarios').update(cambios).eq('id', id);
        if (updateError) return respond({ ok: false, error: updateError.code === '23505' ? 'Ese nombre de usuario ya existe.' : 'No se pudo guardar la edición.' }, 400);
      }
      if (cambiandoPassword) {
        const { error: cambioAuthError } = await db.auth.admin.updateUserById(id, {
          password: passwordNuevo,
          email_confirm: true,
        });
        if (cambioAuthError) {
          if (Object.keys(cambios).length) {
            const { error: rollbackError } = await db.from('usuarios').update({
              nombre: actual.nombre, nombre_usuario: actual.nombre_usuario,
              rol: actual.rol, activo: actual.activo,
            }).eq('id', id);
            if (rollbackError) console.error('Falló reversión de perfil:', rollbackError.message);
          }
          return respond({ ok: false, error: 'No se pudo cambiar la contraseña.' }, 400);
        }
      }
      await auditar('editar_usuario', id, {
        campos: Object.keys(cambios), password_actualizada: cambiandoPassword,
      });
      return respond({ ok: true });
    }
    return respond({ ok: false, error: 'Acción no reconocida.' }, 400);
  } catch (e) {
    console.error('Error en gestionar-usuarios:', e instanceof Error ? e.message : String(e));
    return respond({ ok: false, error: 'No se pudo completar la operación.' }, 500);
  }
});
