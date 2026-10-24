import { invocarEvento } from '../lib/evento';
import { useCallback, useEffect, useState } from 'react';
import { RefreshCw, Search, ChevronLeft, ChevronRight, TicketCheck, CreditCard } from 'lucide-react';
import { supabase } from '../lib/supabase';
import DetalleParticipante from './DetalleParticipante';

type Tipo = 'pagos' | 'invitaciones';
type Fila = {
  registro_id: string; folio: string; nombre: string; telefono: string; asesor: string;
  registro_estado: string; exento_pago: boolean; pago_id?: string; pago_estado?: string;
  importe?: number | null; referencia?: string | null; invitacion_id?: string | null;
  invitacion_estado?: string; fecha?: string | null;
};
type Respuesta = { ok: boolean; error?: string; total: number; pagina: number; limite: number; registros: Fila[]; limitado?: boolean };
const primary: React.CSSProperties = { background: '#a33460', color: 'white', border: 0, padding: '10px 14px', borderRadius: 10, cursor: 'pointer', fontWeight: 600 };
const secondary: React.CSSProperties = { ...primary, background: 'white', color: '#a33460', border: '1px solid #edc4d3' };
const date = (v?: string | null) => v ? new Date(v).toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' }) : '—';
export default function BandejaAdmin({ tipo }: { tipo: Tipo }) {
  const [filas, setFilas] = useState<Fila[]>([]);
  const [total, setTotal] = useState(0);
  const [pagina, setPagina] = useState(1);
  const [texto, setTexto] = useState('');
  const [filtro, setFiltro] = useState('');
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState('');
  const [seleccionado, setSeleccionado] = useState<string | null>(null);
  const [limitado, setLimitado] = useState(false);
  const cargar = useCallback(async () => {
    setCargando(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Tu sesión expiró. Inicia sesión nuevamente.');
      const { data, error: fallo } = await invocarEvento('bandejas-admin', {
        body: { tipo, pagina, busqueda: filtro },
        headers: { Authorization: `Bearer ${session.access_token}` }
      });
      const r = data as Respuesta | null;
      if (fallo || !r?.ok) throw new Error(r?.error || fallo?.message || 'No se pudo consultar la bandeja');
      setFilas(r.registros || []); setTotal(r.total || 0); setLimitado(Boolean(r.limitado)); setError('');
    } catch (e) { setError(e instanceof Error ? e.message : 'Error desconocido'); }
    finally { setCargando(false); }
  }, [tipo, pagina, filtro]);
  // eslint-disable-next-line react-hooks/set-state-in-effect -- Sincroniza una consulta externa y su estado de carga.
  useEffect(() => { void cargar(); }, [cargar]);

  const pagos = tipo === 'pagos';
  const titulo = pagos ? 'Validación de pagos' : 'Invitaciones QR';
  return <section style={{ color: '#493640' }}>
    <h2 style={{ color: '#a33460', display: 'flex', alignItems: 'center', gap: 10 }}>{pagos ? <CreditCard /> : <TicketCheck />}{titulo}</h2>
    <p style={{ color: '#786770' }}>{pagos ? 'Bandeja exclusiva de comprobantes pendientes o en revisión. Abre la ficha para aprobar o rechazar.' : 'Estado de las invitaciones por participante. Abre su ficha para gestionar recuperación o reemisión de forma segura.'}</p>
    <div style={{ background: 'white', border: '1px solid #f0d5df', borderRadius: 18, padding: 20 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
        <div><strong style={{ color: '#a33460', fontSize: 28 }}>{total}</strong><div style={{ color: '#786770' }}>{pagos ? 'Comprobantes por revisar' : 'Participantes'}</div></div>
        <button type="button" style={secondary} disabled={cargando} onClick={() => void cargar()}><RefreshCw size={15} style={{ verticalAlign: 'middle' }} /> Actualizar</button>
      </div>
      <form onSubmit={e => { e.preventDefault(); setPagina(1); setFiltro(texto.trim()); }} style={{ display: 'flex', gap: 10, margin: '18px 0', flexWrap: 'wrap' }}>
        <input aria-label="Buscar" placeholder="Nombre, folio, WhatsApp o asesor" value={texto} onChange={e => setTexto(e.target.value)} style={{ flex: '1 1 240px', minWidth: 0, padding: 12, border: '1px solid #edc4d3', borderRadius: 10 }} />
        <button type="submit" style={primary}><Search size={15} style={{ verticalAlign: 'middle' }} /> Buscar</button>
      </form>
      {error && <p role="alert" style={{ color: '#a33460' }}>{error}. Verifica que hayas desplegado la función bandejas-admin.</p>}
      {limitado && <p style={{ color: '#9b7740' }}>El listado alcanzó el límite de consulta del servidor. Se requiere paginación adicional para más de 1,000 registros.</p>}
      <div style={{ overflowX: 'auto' }}><table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 760, textAlign: 'left' }}>
        <thead style={{ background: '#fff0f5', color: '#96315a' }}><tr>{['Participante', 'Folio', 'Asesor', pagos ? 'Importe' : 'Invitación', pagos ? 'Referencia' : 'Fecha emisión', 'Acción'].map(h => <th key={h} style={{ padding: 12 }}>{h}</th>)}</tr></thead>
        <tbody>{filas.map(f => <tr key={pagos ? f.pago_id : f.registro_id} style={{ borderBottom: '1px solid #f3e2e9' }}>
          <td style={{ padding: 12 }}><strong>{f.nombre}</strong><div style={{ fontSize: 12, color: '#786770' }}>{f.telefono}</div></td>
          <td style={{ padding: 12 }}>{f.folio}</td><td style={{ padding: 12 }}>{f.asesor || '—'}</td>
          <td style={{ padding: 12 }}>{pagos ? `$${Number(f.importe || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}` : <span style={{ color: f.invitacion_estado === 'emitida' || f.invitacion_estado === 'activa' ? '#197448' : '#9b7740', fontWeight: 600 }}>{f.invitacion_estado === 'sin_emitir' ? 'Sin emitir' : f.invitacion_estado}</span>}</td>
          <td style={{ padding: 12 }}>{pagos ? f.referencia || '—' : date(f.fecha)}</td>
          <td style={{ padding: 12 }}><button type="button" style={secondary} onClick={() => setSeleccionado(f.registro_id)}>{pagos ? 'Revisar pago' : 'Gestionar QR'}</button></td>
        </tr>)}</tbody>
      </table></div>
      {!cargando && !error && filas.length === 0 && <p style={{ textAlign: 'center', padding: 25, color: '#786770' }}>{pagos ? 'No hay comprobantes pendientes con este filtro.' : 'No se encontraron participantes.'}</p>}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 18 }}>
        <button type="button" style={secondary} disabled={pagina <= 1 || cargando} onClick={() => setPagina(p => p - 1)}><ChevronLeft size={15} style={{ verticalAlign: 'middle' }} /> Anterior</button>
        <span>Página {pagina} / {Math.max(1, Math.ceil(total / 20))}</span>
        <button type="button" style={secondary} disabled={pagina * 20 >= total || cargando} onClick={() => setPagina(p => p + 1)}>Siguiente <ChevronRight size={15} style={{ verticalAlign: 'middle' }} /></button>
      </div>
    </div>
    {seleccionado && <DetalleParticipante key={seleccionado} registroId={seleccionado} onCerrar={() => { setSeleccionado(null); void cargar(); }} onPagoActualizado={() => void cargar()} />}
  </section>;
}
