import { useCallback, useEffect, useState } from 'react';
import { Users, ClipboardCheck, QrCode, ScanLine, LogOut, History, RefreshCw, CheckCircle2, Clock3, UserCog, FlaskConical } from 'lucide-react';
import ParticipantesAdmin from './ParticipantesAdmin';
import ControlAcceso from './ControlAcceso';
import RegistroAccesos, { type Resumen } from './RegistroAccesos';
import BandejaAdmin from './BandejaAdmin';
import UsuariosAdmin from './UsuariosAdmin';
import Registro from './Registro';
import { supabase } from '../lib/supabase';

type Props = { onSalir: () => void };
type CupoEvento = {
  capacidad: number;
  ocupados: number;
  disponibles: number;
  con_pago: number;
  cortesias: number;
  pendientes: number;
  pruebas: number;
  porcentaje: number;
};
type Vista = 'inicio' | 'participantes' | 'pagos' | 'invitaciones' | 'escaner' | 'historial' | 'usuarios' | 'registro-prueba';
const baseCard: React.CSSProperties = { background: '#fff', border: '1px solid #f0d5df', borderRadius: 18, padding: 22 };
const boton: React.CSSProperties = { border: 'none', background: '#a33460', color: 'white', padding: '11px 16px', borderRadius: 10, cursor: 'pointer', fontWeight: 700 };
export default function PanelAdmin({ onSalir }: Props) {
  const [nombre, setNombre] = useState('Administrador');
  const [saliendo, setSaliendo] = useState(false);
  const [vista, setVista] = useState<Vista>('inicio');
  const [resumen, setResumen] = useState<Resumen | null>(null);
  const [error, setError] = useState('');
  const [cupo, setCupo] = useState<CupoEvento | null>(null);
  const [errorCupo, setErrorCupo] = useState('');
  const [cargando, setCargando] = useState(false);
  const actualizar = useCallback(async () => {
    setCargando(true);
    try {
      const { data, error: fallo } = await supabase.functions.invoke('resumen-accesos', { body: { solo_resumen: true } });
      if (fallo || !data?.ok) throw new Error(data?.error || fallo?.message || 'No se pudo cargar el resumen');
      setResumen(data.resumen as Resumen); setError('');
    } catch (e) { setError(e instanceof Error ? e.message : 'No se pudo cargar el resumen'); }
    try {
      const { data, error: fallo } = await supabase.functions.invoke('resumen-cupo-evento', { body: {} });
      if (fallo || !data?.ok || !data.cupo) throw new Error(data?.error || fallo?.message || 'No se pudo consultar el cupo');
      setCupo(data.cupo as CupoEvento);
      setErrorCupo('');
    } catch (e) {
      setCupo(null);
      setErrorCupo(e instanceof Error ? e.message : 'No se pudo actualizar el cupo');
    } finally { setCargando(false); }
  }, []);
  useEffect(() => { void supabase.auth.getUser().then(({ data }) => { if (data.user?.email) setNombre(data.user.email); }); void actualizar(); }, [actualizar]);
  useEffect(() => { const id = window.setInterval(() => { void actualizar(); }, 30000); return () => window.clearInterval(id); }, [actualizar]);
  async function salir() { if (saliendo) return; setSaliendo(true); const { error: fallo } = await supabase.auth.signOut(); if (fallo) { setSaliendo(false); alert('No se pudo cerrar sesión'); return; } onSalir(); }
  const indicadores = [
    { titulo: 'Participantes', valor: resumen?.participantes, icono: <Users size={22} /> },
    { titulo: 'Confirmados', valor: resumen?.confirmados, icono: <CheckCircle2 size={22} /> },
    { titulo: 'Pagos pendientes', valor: resumen?.pagos_pendientes, icono: <Clock3 size={22} /> },
    { titulo: 'Ya ingresaron', valor: resumen?.ingresos, icono: <ScanLine size={22} /> },
  ];
  const modulos: { vista: Vista; titulo: string; descripcion: string; accion: string; icono: React.ReactNode }[] = [
    { vista: 'registro-prueba', titulo: 'Registro de prueba', descripcion: 'Probar fotografía, comprobante y pago sin abrir las inscripciones públicas.', accion: 'Crear prueba', icono: <FlaskConical size={28} /> },
    { vista: 'participantes', titulo: 'Participantes', descripcion: 'Buscar inscripciones, consultar fichas y gestionar sus pagos e invitaciones.', accion: 'Ver participantes', icono: <Users size={28} /> },
    { vista: 'pagos', titulo: 'Validación de pagos', descripcion: 'Bandeja independiente de comprobantes pendientes y en revisión.', accion: 'Revisar pagos', icono: <ClipboardCheck size={28} /> },
    { vista: 'invitaciones', titulo: 'Invitaciones QR', descripcion: 'Consultar estados de QR y gestionar invitaciones por participante.', accion: 'Gestionar invitaciones', icono: <QrCode size={28} /> },
    { vista: 'escaner', titulo: 'Control de acceso', descripcion: 'Escanear QR con Zebra o cámara y autorizar entradas.', accion: 'Abrir escáner', icono: <ScanLine size={28} /> },
    { vista: 'usuarios', titulo: 'Administración de usuarios', descripcion: 'Crear usuarios y contraseñas, editar datos, cambiar roles y activar o desactivar cuentas.', accion: 'Gestionar usuarios', icono: <UserCog size={28} /> },
    { vista: 'historial', titulo: 'Registro de accesos', descripcion: 'Ver quién ingresó, a qué hora y quién autorizó.', accion: 'Ver ingresos', icono: <History size={28} /> },
  ];
  return <main style={{ minHeight: '100vh', background: '#fff6f9', padding: 24, color: '#4b3440' }}>
    <header style={{ maxWidth: 1100, margin: '0 auto 25px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
      <div><h1 style={{ color: '#a33460', margin: 0 }}>JOYERÍA AMOR</h1><p style={{ marginTop: 6, color: '#826b75' }}>Evento Anual 2026 · {nombre}</p></div>
      <button type="button" onClick={() => void salir()} disabled={saliendo} style={{ ...boton, background: '#fff', color: '#a33460', border: '1px solid #e5bdcc' }}><LogOut size={17} style={{ verticalAlign: 'middle' }} /> {saliendo ? 'Cerrando...' : 'Cerrar sesión'}</button>
    </header>
    <section style={{ maxWidth: 1100, margin: '0 auto' }}>
      {vista !== 'inicio' && vista !== 'registro-prueba' && <button type="button" onClick={() => { setVista('inicio'); void actualizar(); }} style={{ ...boton, marginBottom: 18, background: '#fff', color: '#a33460', border: '1px solid #e5bdcc' }}>← Volver al panel</button>}
      {vista === 'inicio' && <>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}><h2 style={{ margin: 0 }}>Resumen del evento</h2><button type="button" onClick={() => void actualizar()} disabled={cargando} style={{ ...boton, background: '#fff', color: '#a33460', border: '1px solid #e5bdcc' }}><RefreshCw size={16} style={{ verticalAlign: 'middle' }} /> Actualizar</button></div>
        {error && <p role="alert" style={{ color: '#a33460' }}>No se pudo actualizar el resumen: {error}. Comprueba que desplegaste la función resumen-accesos.</p>}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: 14, marginBottom: 24 }}>{indicadores.map(i => <div key={i.titulo} style={baseCard}><div style={{ display: 'flex', justifyContent: 'space-between', color: '#a33460' }}><span>{i.titulo}</span>{i.icono}</div><strong style={{ display: 'block', fontSize: 34, marginTop: 10 }}>{i.valor ?? (cargando ? '…' : '—')}</strong></div>)}</div>
        <section aria-label="Cupo real del evento" style={{ ...baseCard, marginBottom: 24, border: '1px solid #decfa4' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
            <h2 style={{ margin: 0, color: '#805c31', fontSize: 22 }}>Cupo del Evento Anual · 1,500 personas</h2>
            {cupo && <strong style={{ color: cupo.disponibles === 0 ? '#a02940' : '#176747' }}>{cupo.disponibles === 0 ? 'Cupo completo' : `${cupo.disponibles.toLocaleString('es-MX')} lugares disponibles`}</strong>}
          </div>
          <p style={{ color: '#74666d', margin: '10px 0 14px', fontSize: 14 }}>Incluye inscripciones con cuota y cortesías, aun con pago pendiente. No incluye registros de prueba, cancelados ni rechazados.</p>
          {errorCupo && <p role="alert" style={{ color: '#a02940' }}>No se pudo consultar el cupo: {errorCupo}. Comprueba la función resumen-cupo-evento.</p>}
          {cupo && <>
            <div role="progressbar" aria-label="Ocupación del evento" aria-valuenow={cupo.ocupados} aria-valuemin={0} aria-valuemax={cupo.capacidad} style={{ height: 16, background: '#f4e9ee', borderRadius: 10, overflow: 'hidden' }}>
              <div style={{ height: '100%', width: `${Math.min(100, Math.max(0, cupo.porcentaje))}%`, background: cupo.porcentaje >= 90 ? '#b45309' : '#a33460', transition: 'width 250ms ease' }} />
            </div>
            <p style={{ textAlign: 'right', color: '#73636c', marginTop: 5, fontSize: 13 }}>{cupo.ocupados.toLocaleString('es-MX')} de {cupo.capacidad.toLocaleString('es-MX')} lugares · {cupo.porcentaje}%</p>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(155px, 1fr))', gap: 12 }}>
              {[
                ['Ocupados', cupo.ocupados],
                ['Disponibles', cupo.disponibles],
                ['Con cuota', cupo.con_pago],
                ['Cortesías', cupo.cortesias],
                ['Pendientes', cupo.pendientes],
                ['Registros de prueba (no cuentan)', cupo.pruebas],
              ].map(([etiqueta, valor]) => <div key={String(etiqueta)} style={{ background: '#fff9fb', padding: 12, borderRadius: 10, border: '1px solid #f1dde5' }}><span style={{ color: '#745f68', fontSize: 12, display: 'block' }}>{etiqueta}</span><strong style={{ display: 'block', fontSize: 23, color: '#a33460' }}>{Number(valor).toLocaleString('es-MX')}</strong></div>)}
            </div>
            {cupo.disponibles <= 100 && cupo.disponibles > 0 && <p role="status" style={{ color: '#a16207', fontWeight: 700 }}>Atención: quedan 100 lugares o menos.</p>}
            {cupo.disponibles === 0 && <p role="status" style={{ color: '#b42340', fontWeight: 700 }}>Cupo completo. No se permitirán nuevas inscripciones reales.</p>}
          </>}
        </section>
        <h2>Administración</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 16 }}>{modulos.map(m => <article key={m.vista} style={{ ...baseCard, display: 'flex', flexDirection: 'column', gap: 10 }}><div style={{ color: '#a33460' }}>{m.icono}</div><h3 style={{ margin: 0 }}>{m.titulo}</h3><p style={{ color: '#75666c', flex: 1, margin: 0, lineHeight: 1.5 }}>{m.descripcion}</p><button type="button" style={boton} onClick={() => setVista(m.vista)}>{m.accion}</button></article>)}</div>
      </>}
      {vista === 'registro-prueba' && <Registro modoPruebaAdmin onVolver={() => { setVista('inicio'); void actualizar(); }} />}
      {vista === 'participantes' && <ParticipantesAdmin />}
      {vista === 'pagos' && <BandejaAdmin tipo="pagos" />}
      {vista === 'invitaciones' && <BandejaAdmin tipo="invitaciones" />}
      {vista === 'escaner' && <ControlAcceso />}
      {vista === 'historial' && <RegistroAccesos />}
      {vista === 'usuarios' && <UsuariosAdmin />}
    </section>
  </main>;
}
