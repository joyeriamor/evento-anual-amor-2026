import { supabase } from './supabase';

/** El servidor asigna el rol; nunca se confía en el nombre de usuario ni en metadata del navegador. */
export type RolPantalla = 'admin' | 'validador' | 'recepcion' | 'acceso';
export type ResultadoAcceso = { rol: RolPantalla | null; error: string | null };

function rolPantalla(rol: unknown): RolPantalla | null {
  if (rol === 'administrador') return 'admin';
  if (rol === 'validador' || rol === 'recepcion' || rol === 'acceso') return rol;
  return null;
}

type FalloFuncion = { message?: string; context?: unknown };

async function detalleFalloFuncion(error: unknown): Promise<{ status: number | null; descripcion: string }> {
  if (!error) return { status: null, descripcion: '' };
  const fallo = error as FalloFuncion;
  const contexto = fallo.context;
  if (typeof Response !== 'undefined' && contexto instanceof Response) {
    let descripcion = '';
    try {
      const cuerpo: unknown = await contexto.clone().json();
      if (cuerpo && typeof cuerpo === 'object') {
        const objeto = cuerpo as Record<string, unknown>;
        descripcion = typeof objeto.error === 'string' ? objeto.error :
          typeof objeto.message === 'string' ? objeto.message : '';
      }
    } catch { /* Error del gateway sin JSON. */ }
    return { status: contexto.status, descripcion: descripcion || fallo.message || '' };
  }
  return { status: null, descripcion: fallo.message || 'Error de comunicación.' };
}

/**
 * Verifica el JWT y el rol ACTIVO exclusivamente mediante verificar-personal.
 * No lee public.usuarios directamente; su RLS bloquearía al empleado.
 */
export async function verificarRolAccesoDetallado(token: string): Promise<ResultadoAcceso> {
  if (!token) return { rol: null, error: 'La sesión no tiene un token válido.' };

  // La función de personal contempla TODOS los roles, incluidos administradores.
  const { data: personal, error: errorPersonal } = await supabase.functions.invoke('verificar-personal', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: {},
  });
  if (!errorPersonal && personal?.ok === true && personal?.autorizado === true) {
    const rol = rolPantalla(personal.usuario?.rol);
    if (rol) return { rol, error: null };
  }

  const fallo = await detalleFalloFuncion(errorPersonal);
  if (fallo.status === 404 || /function not found|not found/i.test(fallo.descripcion)) {
    return { rol: null, error: "Falta desplegar la función 'verificar-personal'. Sigue los pasos del parche de acceso." };
  }
  if (fallo.status === 401) {
    return { rol: null, error: 'Supabase rechazó el token al consultar verificar-personal (401). Revisa que la función esté desplegada y el JWT sea válido.' };
  }
  if (fallo.status === 403) {
    return { rol: null, error: fallo.descripcion || 'La cuenta no está activa o no tiene un rol autorizado. Revisa Administración de usuarios.' };
  }
  if (fallo.status === 500) {
    return { rol: null, error: 'La función verificar-personal presentó un error interno (500). Consulta sus registros en Supabase → Edge Functions → Logs.' };
  }
  if (!errorPersonal && personal?.autorizado === false) {
    const descripcion = typeof personal?.error === 'string' ? personal.error : '';
    return { rol: null, error: descripcion || 'La cuenta no está activa o no tiene un rol autorizado. Revisa Administración de usuarios.' };
  }
  if (errorPersonal) {
    return { rol: null, error: `No se pudo consultar verificar-personal${fallo.status ? ` (HTTP ${fallo.status})` : ''}. ${fallo.descripcion}`.trim() };
  }
  return { rol: null, error: 'El servidor no confirmó un rol autorizado para esta cuenta. Comprueba que el perfil tenga activo=true y el rol correcto.' };
}

/** Compatibilidad con App.tsx, que usa únicamente el rol para recuperar sesiones. */
export async function verificarRolAcceso(token: string): Promise<RolPantalla | null> {
  return (await verificarRolAccesoDetallado(token)).rol;
}
