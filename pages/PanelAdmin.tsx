import { useCallback, useEffect, useState } from 'react';
import { Users, ClipboardCheck, QrCode, ScanLine, LogOut, History, RefreshCw, CheckCircle2, Clock3, UserCog } from 'lucide-react';
import ParticipantesAdmin from './ParticipantesAdmin';
import ControlAcceso from './ControlAcceso';
import RegistroAccesos, { type Resumen } from './RegistroAccesos';
import BandejaAdmin from './BandejaAdmin';
import UsuariosAdmin from './UsuariosAdmin';
import { supabase } from '../lib/supabase';

type Props = { onSalir: () => void };
type Vista = 'inicio' | 'participantes' | 'pagos' | 'invitaciones' | 'escaner' | 'historial' | 'usuarios';
const baseCard: React.CSSProperties = { background: '#fff', border: '1px solid #f0d5df', borderRadius: 18, padding: 22 };
const boton: React.CSSProperties = { border: 'none', background: '#a33460', color: 'white', padding: '11px 16px', borderRadius: 10, cursor: 'pointer', fontWeight: 700 };
export default function PanelAdmin({ onSalir }: Props) {
  const [nombre, setNombre] = useState('Administrador');
  const [saliendo, setSaliendo] = useState(false);
  const [vista, setVista] = useState<Vista>('inicio');
  const [resumen, setResumen] = useState<Resumen | null>(null);
  const [error, setError] = useState('');
  const [cargando, setCargando] = useState(false);
  const actualizar = useCallback(async () => {
    setCargando(true);
    try {
      const { data, error: fallo } = await supabase.functions.invoke('resumen-accesos', { body: { solo_resumen: true } });
      if (fallo || !data?.ok) throw new Error(data?.error || fallo?.message || 'No se pudo cargar el resumen');
      setResumen(data.resumen as Resumen); setError('');
    } catch (e) { setError(e instanceof Error ? e.message : 'No se pudo cargar el resumen'); }
    finally { setCargando(false); }
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
      {vista !== 'inicio' && <button type="button" onClick={() => { setVista('inicio'); void actualizar(); }} style={{ ...boton, marginBottom: 18, background: '#fff', color: '#a33460', border: '1px solid #e5bdcc' }}>← Volver al panel</button>}
      {vista === 'inicio' && <>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}><h2 style={{ margin: 0 }}>Resumen del evento</h2><button type="button" onClick={() => void actualizar()} disabled={cargando} style={{ ...boton, background: '#fff', color: '#a33460', border: '1px solid #e5bdcc' }}><RefreshCw size={16} style={{ verticalAlign: 'middle' }} /> Actualizar</button></div>
        {error && <p role="alert" style={{ color: '#a33460' }}>No se pudo actualizar el resumen: {error}. Comprueba que desplegaste la función resumen-accesos.</p>}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: 14, marginBottom: 24 }}>{indicadores.map(i => <div key={i.titulo} style={baseCard}><div style={{ display: 'flex', justifyContent: 'space-between', color: '#a33460' }}><span>{i.titulo}</span>{i.icono}</div><strong style={{ display: 'block', fontSize: 34, marginTop: 10 }}>{i.valor ?? (cargando ? '…' : '—')}</strong></div>)}</div>
        <h2>Administración</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 16 }}>{modulos.map(m => <article key={m.vista} style={{ ...baseCard, display: 'flex', flexDirection: 'column', gap: 10 }}><div style={{ color: '#a33460' }}>{m.icono}</div><h3 style={{ margin: 0 }}>{m.titulo}</h3><p style={{ color: '#75666c', flex: 1, margin: 0, lineHeight: 1.5 }}>{m.descripcion}</p><button type="button" style={boton} onClick={() => setVista(m.vista)}>{m.accion}</button></article>)}</div>
      </>}
      {vista === 'participantes' && <ParticipantesAdmin />}
      {vista === 'pagos' && <BandejaAdmin tipo="pagos" />}
      {vista === 'invitaciones' && <BandejaAdmin tipo="invitaciones" />}
      {vista === 'escaner' && <ControlAcceso />}
      {vista === 'historial' && <RegistroAccesos />}
      {vista === 'usuarios' && <UsuariosAdmin />}
    </section>
  </main>;
}
