import { invocarEvento } from '../lib/evento';
import { useCallback, useEffect, useState, type CSSProperties, type FormEvent } from 'react';
import { Eye, EyeOff, KeyRound, Pencil, UserPlus, X } from 'lucide-react';
import { supabase } from '../lib/supabase';

type Rol = 'administrador' | 'validador' | 'recepcion' | 'acceso';
type Usuario = {
  id: string;
  nombre: string;
  nombre_usuario: string | null;
  rol: Rol;
  activo: boolean;
  created_at: string;
};
type Formulario = {
  nombre: string;
  nombre_usuario: string;
  rol: Rol;
  activo: boolean;
  password: string;
};
const roles: Rol[] = ['administrador', 'validador', 'recepcion', 'acceso'];
const etiquetasRol: Record<Rol, string> = {
  administrador: 'Administrador',
  validador: 'Validador de pagos',
  recepcion: 'Recepción',
  acceso: 'Control de acceso',
};
const boton: CSSProperties = {
  background: '#a33460', color: '#fff', border: 0, borderRadius: 9,
  padding: '10px 14px', fontWeight: 700, cursor: 'pointer',
};
const secundario: CSSProperties = {
  ...boton, background: '#fff', color: '#a33460', border: '1px solid #d9a9bc',
};
const campo: CSSProperties = {
  boxSizing: 'border-box', width: '100%', padding: 11,
  border: '1px solid #dfbac9', borderRadius: 8, minWidth: 0, fontSize: 14,
};
const etiqueta: CSSProperties = { display: 'grid', gap: 6, fontWeight: 600, fontSize: 13 };
const vacio: Formulario = { nombre: '', nombre_usuario: '', rol: 'acceso', activo: true, password: '' };
const patronUsuario = /^[a-z][a-z0-9._-]{2,31}$/;

export default function UsuariosAdmin() {
  const [usuarios, setUsuarios] = useState<Usuario[]>([]);
  const [nuevo, setNuevo] = useState<Formulario>({ ...vacio });
  const [edicion, setEdicion] = useState<Usuario | null>(null);
  const [editar, setEditar] = useState<Formulario>({ ...vacio });
  const [cargando, setCargando] = useState(false);
  const [mostrarPassword, setMostrarPassword] = useState(false);
  const [mostrarPasswordEditar, setMostrarPasswordEditar] = useState(false);
  const [mensaje, setMensaje] = useState('');
  const [error, setError] = useState('');

  const ejecutar = useCallback(async (accion: string, extras: Record<string, unknown> = {}) => {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) throw new Error('La sesión terminó. Entra de nuevo.');
    const { data, error: fallo } = await invocarEvento('gestionar-usuarios', {
      body: { accion, ...extras },
      headers: { Authorization: `Bearer ${session.access_token}` },
    });
    if (fallo || !data?.ok) {
      // Las respuestas de errores HTTP (p.ej., usuario duplicado) están en context.
      let detalle: string | undefined = data?.error;
      if (!detalle && fallo && 'context' in fallo && fallo.context instanceof Response) {
        const cuerpo = await fallo.context.json().catch(() => null);
        detalle = cuerpo?.error;
      }
      throw new Error(detalle || fallo?.message || 'No se completó la operación');
    }
    return data;
  }, []);

  const cargar = useCallback(async () => {
    setCargando(true);
    try {
      const data = await ejecutar('listar');
      setUsuarios((data.usuarios || []) as Usuario[]);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo consultar usuarios');
    } finally {
      setCargando(false);
    }
  }, [ejecutar]);

  // eslint-disable-next-line react-hooks/set-state-in-effect -- Sincroniza una consulta externa y su estado de carga.
  useEffect(() => { void cargar(); }, [cargar]);

  function validar(form: Formulario, requierePassword: boolean): boolean {
    if (form.nombre.trim().length < 2 || !patronUsuario.test(form.nombre_usuario.trim().toLowerCase())) {
      setError('Escribe un nombre válido y un usuario de 3 a 32 caracteres que empiece con letra.');
      return false;
    }
    if ((requierePassword || form.password.length > 0) &&
      !(form.password.length >= 10 && /\p{L}/u.test(form.password) && /\d/u.test(form.password))) {
      setError('La contraseña necesita al menos 10 caracteres, una letra y un número.');
      return false;
    }
    return true;
  }

  async function crear(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(''); setMensaje('');
    if (!validar(nuevo, true)) return;
    setCargando(true);
    try {
      await ejecutar('crear', {
        nombre: nuevo.nombre.trim(), nombre_usuario: nuevo.nombre_usuario.trim().toLowerCase(),
        rol: nuevo.rol, password: nuevo.password,
      });
      const creado = nuevo.nombre_usuario.trim().toLowerCase();
      setNuevo({ ...vacio }); setMostrarPassword(false);
      setMensaje(`Usuario «${creado}» creado. Ya puede entrar con la contraseña que asignaste. Compártela por un medio seguro.`);
      await cargar();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo crear el usuario.');
    } finally {
      setCargando(false);
    }
  }

  function abrirEdicion(usuario: Usuario) {
    setEdicion(usuario);
    setEditar({
      nombre: usuario.nombre || '', nombre_usuario: usuario.nombre_usuario || '',
      rol: usuario.rol, activo: usuario.activo, password: '',
    });
    setMostrarPasswordEditar(false); setError(''); setMensaje('');
  }

  async function guardar(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!edicion) return;
    setError(''); setMensaje('');
    if (!validar(editar, false)) return;
    if (!edicion.nombre_usuario && edicion.rol !== 'administrador' && !editar.password) {
      setError('Para convertir esta cuenta invitada, escribe también su contraseña inicial.');
      return;
    }
    const passwordCambia = editar.password.length > 0;
    if (passwordCambia && !window.confirm(`¿Cambiar la contraseña de ${edicion.nombre}? La contraseña anterior dejará de funcionar.`)) return;
    setCargando(true);
    try {
      await ejecutar('actualizar', {
        id: edicion.id, nombre: editar.nombre.trim(),
        nombre_usuario: editar.nombre_usuario.trim().toLowerCase(),
        rol: editar.rol, activo: editar.activo,
        ...(passwordCambia ? { password: editar.password } : {}),
      });
      setEdicion(null); setEditar({ ...vacio }); setMostrarPasswordEditar(false);
      setMensaje(`Datos de «${editar.nombre_usuario.trim().toLowerCase()}» actualizados.${passwordCambia ? ' Contraseña actualizada.' : ''}`);
      await cargar();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudieron guardar los cambios.');
    } finally {
      setCargando(false);
    }
  }

  return (
    <section style={{ display: 'grid', gap: 18 }}>
      <div>
        <h2 style={{ color: '#a33460', marginBottom: 4 }}>Administración de usuarios</h2>
        <p style={{ color: '#74636c' }}>Crea cuentas con usuario y contraseña, sin invitaciones por correo. Edita los datos cuando lo necesites.</p>
      </div>

      <form onSubmit={(e) => void crear(e)} style={{ background: '#fff', border: '1px solid #eed2de', borderRadius: 16, padding: 20, display: 'grid', gap: 14 }}>
        <h3 style={{ margin: 0, display: 'flex', gap: 8, alignItems: 'center' }}><UserPlus size={20} /> Crear empleado</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(210px,1fr))', gap: 12 }}>
          <label style={etiqueta}>Nombre completo
            <input style={campo} required minLength={2} maxLength={120} value={nuevo.nombre}
              onChange={(e) => setNuevo({ ...nuevo, nombre: e.target.value })} placeholder="Ej. María Hernández" />
          </label>
          <label style={etiqueta}>Nombre de usuario
            <input style={campo} required minLength={3} maxLength={32} value={nuevo.nombre_usuario}
              onChange={(e) => setNuevo({ ...nuevo, nombre_usuario: e.target.value.toLowerCase() })}
              autoCapitalize="off" autoCorrect="off" spellCheck={false} placeholder="Ej. recepcion01" />
          </label>
          <label style={etiqueta}>Rol
            <select style={campo} value={nuevo.rol} onChange={(e) => setNuevo({ ...nuevo, rol: e.target.value as Rol })}>
              {roles.map((r) => <option key={r} value={r}>{etiquetasRol[r]}</option>)}
            </select>
          </label>
          <label style={etiqueta}>Contraseña inicial
            <span style={{ display: 'flex', gap: 6 }}>
              <input style={campo} required minLength={10} maxLength={128} type={mostrarPassword ? 'text' : 'password'}
                autoComplete="new-password" value={nuevo.password}
                onChange={(e) => setNuevo({ ...nuevo, password: e.target.value })} placeholder="Mínimo 10 caracteres" />
              <button type="button" style={secundario} aria-label={mostrarPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'}
                onClick={() => setMostrarPassword(!mostrarPassword)}>{mostrarPassword ? <EyeOff size={17} /> : <Eye size={17} />}</button>
            </span>
          </label>
        </div>
        <p style={{ color: '#7e6571', margin: 0, fontSize: 13 }}>La contraseña debe tener al menos 10 caracteres, una letra y un número. No se enviará ningún correo y la contraseña no se guarda en el panel.</p>
        <div><button type="submit" style={boton} disabled={cargando}>{cargando ? 'Guardando…' : 'Crear usuario'}</button></div>
      </form>

      {error && <p role="alert" style={{ color: '#a1203c', padding: 12, borderRadius: 9, background: '#ffecf0', margin: 0 }}>{error}</p>}
      {mensaje && <p role="status" style={{ color: '#166534', padding: 12, borderRadius: 9, background: '#ebf8ed', margin: 0 }}>{mensaje}</p>}

      <div style={{ background: '#fff', border: '1px solid #eed2de', borderRadius: 16, padding: 18, overflowX: 'auto' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
          <h3>Usuarios registrados ({usuarios.length})</h3>
          <button type="button" style={secundario} onClick={() => void cargar()} disabled={cargando}>Actualizar</button>
        </div>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead><tr>{['Nombre', 'Usuario', 'Rol', 'Estado', 'Acciones'].map((t) =>
            <th key={t} style={{ padding: 10, borderBottom: '1px solid #eed2de' }}>{t}</th>)}</tr></thead>
          <tbody>
            {usuarios.map((u) => <tr key={u.id}>
              <td style={{ padding: 10, borderBottom: '1px solid #f7eaf0' }}>{u.nombre}</td>
              <td style={{ padding: 10, borderBottom: '1px solid #f7eaf0' }}>
                {u.nombre_usuario ? <strong>{u.nombre_usuario}</strong> : <span style={{ color: '#ad642e' }}>Sin asignar</span>}
              </td>
              <td style={{ padding: 10, borderBottom: '1px solid #f7eaf0' }}>{etiquetasRol[u.rol] ?? u.rol}</td>
              <td style={{ padding: 10, borderBottom: '1px solid #f7eaf0', color: u.activo ? '#166534' : '#b42345' }}>{u.activo ? 'Activo' : 'Inactivo'}</td>
              <td style={{ padding: 10, borderBottom: '1px solid #f7eaf0' }}>
                <button type="button" style={secundario} disabled={cargando}
                  onClick={() => abrirEdicion(u)}><Pencil size={15} style={{ verticalAlign: 'middle', marginRight: 5 }} />Editar</button>
              </td>
            </tr>)}
          </tbody>
        </table>
        {!cargando && usuarios.length === 0 && <p>No hay usuarios registrados.</p>}
      </div>

      {edicion && <form onSubmit={(e) => void guardar(e)} style={{
        background: '#fff', border: '2px solid #d8a1b9', borderRadius: 16, padding: 20,
        display: 'grid', gap: 14,
      }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'space-between' }}>
          <h3 style={{ color: '#a33460', margin: 0 }}>Editar: {edicion.nombre}</h3>
          <button type="button" style={secundario} onClick={() => setEdicion(null)}><X size={17} /> Cerrar</button>
        </div>
        {!edicion.nombre_usuario && <p style={{ margin: 0, color: '#935628' }}>
          Esta cuenta se creó mediante invitación. Asígnale un usuario y una contraseña nueva para que pueda entrar sin correo.
        </p>}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(210px,1fr))', gap: 12 }}>
          <label style={etiqueta}>Nombre completo
            <input style={campo} required minLength={2} maxLength={120} value={editar.nombre}
              onChange={(e) => setEditar({ ...editar, nombre: e.target.value })} />
          </label>
          <label style={etiqueta}>Nombre de usuario
            <input style={campo} required minLength={3} maxLength={32} value={editar.nombre_usuario}
              autoCapitalize="off" autoCorrect="off" spellCheck={false}
              onChange={(e) => setEditar({ ...editar, nombre_usuario: e.target.value.toLowerCase() })} />
          </label>
          <label style={etiqueta}>Rol
            <select style={campo} value={editar.rol} onChange={(e) => setEditar({ ...editar, rol: e.target.value as Rol })}>
              {roles.map((r) => <option key={r} value={r}>{etiquetasRol[r]}</option>)}
            </select>
          </label>
          <label style={etiqueta}>Estado
            <select style={campo} value={editar.activo ? 'activo' : 'inactivo'} onChange={(e) => setEditar({ ...editar, activo: e.target.value === 'activo' })}>
              <option value="activo">Activo</option><option value="inactivo">Inactivo</option>
            </select>
          </label>
          <label style={etiqueta}>Cambiar contraseña (opcional)
            <span style={{ display: 'flex', gap: 6 }}>
              <input style={campo} minLength={10} maxLength={128} type={mostrarPasswordEditar ? 'text' : 'password'}
                autoComplete="new-password" value={editar.password} placeholder="Vacío = conservar contraseña"
                onChange={(e) => setEditar({ ...editar, password: e.target.value })} />
              <button type="button" style={secundario} aria-label={mostrarPasswordEditar ? 'Ocultar contraseña' : 'Mostrar contraseña'}
                onClick={() => setMostrarPasswordEditar(!mostrarPasswordEditar)}>{mostrarPasswordEditar ? <EyeOff size={17} /> : <Eye size={17} />}</button>
            </span>
          </label>
        </div>
        <p style={{ color: '#74636c', margin: 0, fontSize: 13, display: 'flex', gap: 6, alignItems: 'center' }}>
          <KeyRound size={16} /> La contraseña actual no puede consultarse. Si escribes una nueva, reemplazará la anterior.
        </p>
        <div style={{ display: 'flex', gap: 9, flexWrap: 'wrap' }}>
          <button type="submit" style={boton} disabled={cargando}>{cargando ? 'Guardando…' : 'Guardar cambios'}</button>
          <button type="button" style={secundario} onClick={() => setEdicion(null)}>Cancelar</button>
        </div>
      </form>}
    </section>
  );
}
