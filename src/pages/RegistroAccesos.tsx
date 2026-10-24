import { invocarEvento } from '../lib/evento';
import { useCallback, useEffect, useState } from 'react';
import { Download, RefreshCw, Search } from 'lucide-react';


export type Resumen = { participantes: number; confirmados: number; pendientes: number; pagos_pendientes: number; ingresos: number };
type Ingreso = { id: string; nombre: string; folio: string; asesor: string; operador: string; ingresado_at: string; foto_url: string | null };
type Resultado = { ok: boolean; error?: string; resumen: Resumen; ingresos: Ingreso[]; total_historial: number; pagina: number; limite: number; historial_limitado?: boolean };
const formatoFecha = (fecha: string) => new Date(fecha).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' });
const estiloBoton: React.CSSProperties = { border: '1px solid #e9c9d6', borderRadius: 10, background: '#fff', color: '#a33460', padding: '10px 13px', cursor: 'pointer', fontWeight: 600 };

export default function RegistroAccesos() {
  const [pagina, setPagina] = useState(1);
  const [busqueda, setBusqueda] = useState('');
  const [filtro, setFiltro] = useState('');
  const [resultado, setResultado] = useState<Resultado | null>(null);
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState('');
  const cargar = useCallback(async () => {
    setCargando(true); setError('');
    try {
      const { data, error: fallo } = await invocarEvento('resumen-accesos', { body: { pagina, busqueda: filtro } });
      if (fallo || !data?.ok) throw new Error(data?.error || fallo?.message || 'No se pudo consultar el historial');
      setResultado(data as Resultado);
    } catch (e) { setError(e instanceof Error ? e.message : 'Error al consultar'); }
    finally { setCargando(false); }
  }, [pagina, filtro]);
  // eslint-disable-next-line react-hooks/set-state-in-effect -- Sincroniza una consulta externa y su estado de carga.
  useEffect(() => { void cargar(); }, [cargar]);
  useEffect(() => { const id = window.setInterval(() => { void cargar(); }, 30000); return () => window.clearInterval(id); }, [cargar]);
  function exportar() {
    if (!resultado?.ingresos.length) return;
    const escapar = (v: string) => `"${v.replaceAll('"', '""')}"`;
    const filas = [['Nombre', 'Folio', 'Asesor', 'Operador', 'Fecha y hora'], ...resultado.ingresos.map(r => [r.nombre, r.folio, r.asesor, r.operador, formatoFecha(r.ingresado_at)])];
    const csv = '\uFEFF' + filas.map(row => row.map(escapar).join(',')).join('\r\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    const a = document.createElement('a'); a.href = url; a.download = `accesos-amor-pagina-${pagina}.csv`; a.click(); URL.revokeObjectURL(url);
  }
  return <section style={{ background: '#fff', border: '1px solid #f0d5df', borderRadius: 18, padding: 22, marginTop: 20 }}>
    <h2 style={{ color: '#a33460', marginTop: 0 }}>Registro de accesos</h2>
    <p style={{ color: '#75666c' }}>Historial de entradas registradas. Actualización automática cada 30 segundos.</p>
    <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 18 }}>
      <form onSubmit={e => { e.preventDefault(); setPagina(1); setFiltro(busqueda); }} style={{ display: 'flex', gap: 8, flex: 1 }}>
        <input value={busqueda} onChange={e => setBusqueda(e.target.value)} placeholder="Nombre, folio, asesor u operador" aria-label="Buscar ingresos" style={{ padding: 11, border: '1px solid #e9c9d6', borderRadius: 10, flex: 1, minWidth: 140 }} />
        <button style={estiloBoton}><Search size={16} /> Buscar</button>
      </form>
      <button type="button" onClick={() => void cargar()} disabled={cargando} style={estiloBoton}><RefreshCw size={16} /> Actualizar</button>
      <button type="button" onClick={exportar} disabled={!resultado?.ingresos.length} style={estiloBoton}><Download size={16} /> CSV de esta página</button>
    </div>
    {error && <p role="alert" style={{ color: '#b42318' }}>{error}</p>}
    {cargando && <p>Consultando ingresos...</p>}
    {resultado && <>
      <p><strong>{resultado.resumen.ingresos}</strong> entradas registradas · <strong>{resultado.total_historial}</strong> resultados en el historial consultado</p>
      {resultado.historial_limitado && <p style={{ color: '#9b6b00' }}>El historial muestra hasta los últimos 1000 ingresos. Para exportaciones completas se necesitará paginación del servidor.</p>}
      <div style={{ overflowX: 'auto' }}><table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
        <thead><tr>{['Participante', 'Folio', 'Asesor', 'Operador', 'Fecha y hora'].map(t => <th key={t} style={{ padding: 12, borderBottom: '1px solid #ead3dd' }}>{t}</th>)}</tr></thead>
        <tbody>{resultado.ingresos.map(r => <tr key={r.id}>
          <td style={{ padding: 10, borderBottom: '1px solid #f3e5ea' }}><div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>{r.foto_url ? <img src={r.foto_url} alt="Foto participante" style={{ width: 44, height: 50, objectFit: 'cover', borderRadius: 7 }} /> : <span aria-label="Sin foto" style={{ width: 44, height: 50, background: '#f7edf1', borderRadius: 7, display: 'grid', placeItems: 'center', fontSize: 11 }}>Sin foto</span>}<strong>{r.nombre}</strong></div></td>
          <td style={{ padding: 10 }}>{r.folio}</td><td style={{ padding: 10 }}>{r.asesor || '—'}</td><td style={{ padding: 10 }}>{r.operador}</td><td style={{ padding: 10, whiteSpace: 'nowrap' }}>{formatoFecha(r.ingresado_at)}</td>
        </tr>)}</tbody></table></div>
      {!resultado.ingresos.length && <p>No hay ingresos para esta búsqueda.</p>}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 16 }}>
        <button type="button" style={estiloBoton} disabled={pagina <= 1} onClick={() => setPagina(p => p - 1)}>Anterior</button>
        <span>Página {pagina}</span>
        <button type="button" style={estiloBoton} disabled={pagina * resultado.limite >= resultado.total_historial} onClick={() => setPagina(p => p + 1)}>Siguiente</button>
      </div>
    </>}
  </section>;
}
