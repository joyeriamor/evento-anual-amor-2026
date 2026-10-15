import { useCallback, useEffect, useState, type CSSProperties, type FormEvent } from 'react';
import { ClipboardCheck, LogOut, RefreshCw, Search, Users, ChevronLeft, ChevronRight, ShieldCheck, Printer, Download } from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { supabase } from '../lib/supabase';
import { generarInvitacionNavidena } from '../lib/generarInvitacionNavidena';

type Rol = 'validador' | 'recepcion';
type Fila = {
  registro_id: string;
  nombre: string;
  telefono: string;
  folio: string;
  registro_estado: string;
  exento_pago: boolean;
  fecha: string;
  pago_id?: string | null;
  pago_estado?: string | null;
  importe?: number | null;
  referencia?: string | null;
  comprobante_url?: string | null;
};
type Respuesta = { ok?: boolean; error?: string; registros?: Fila[]; total?: number; limite?: number; pagina?: number; limitado?: boolean };
const primario: CSSProperties = { border: 0, borderRadius: 10, padding: '11px 15px', color: 'white', background: '#a33460', fontWeight: 700, cursor: 'pointer' };
const secundario: CSSProperties = { ...primario, background: '#fff', color: '#a33460', border: '1px solid #e7c3d1' };
const tarjeta: CSSProperties = { padding: 20, background: 'white', border: '1px solid #ecd1dc', borderRadius: 16 };
const dinero = (n: number | null | undefined) => new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(n || 0);
const fecha = (f?: string) => f ? new Date(f).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' }) : '—';

export default function PanelPersonal({ rol, onSalir }: { rol: Rol; onSalir: () => void }) {
  const pagos = rol === 'validador';
  const [usuario, setUsuario] = useState('Empleado');
  const [filas, setFilas] = useState<Fila[]>([]);
  const [pagina, setPagina] = useState(1);
  const [total, setTotal] = useState(0);
  const [limite, setLimite] = useState(20);
  const [busqueda, setBusqueda] = useState('');
  const [filtro, setFiltro] = useState('');
  const [cargando, setCargando] = useState(false);
  const [operando, setOperando] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [mensaje, setMensaje] = useState('');
  const [limitado, setLimitado] = useState(false);
  const [qr, setQr] = useState<{ token: string; nombre: string; folio: string; telefono: string } | null>(null);
  const [imagenQR, setImagenQR] = useState<{ token: string; url: string; blob: Blob } | null>(null);
  const [errorImagenQR, setErrorImagenQR] = useState('');

  // El token se recibe solo una vez. Preparamos automáticamente una invitación
  // navideña imprimible y descargable antes de permitir cerrar el QR.
  useEffect(() => {
    if (!qr) { setImagenQR(null); setErrorImagenQR(''); return; }

    let activa = true;
    let url: string | null = null;
    setImagenQR(null);
    setErrorImagenQR('');

    const svg = document.querySelector<SVGSVGElement>('#qr-validacion-empleado');
    if (!svg) {
      setErrorImagenQR('No se pudo preparar el QR. Intenta actualizar la vista.');
      return;
    }

    void generarInvitacionNavidena({ qrSvg: svg, nombre: qr.nombre, folio: qr.folio })
      .then((blob) => {
        url = URL.createObjectURL(blob);
        if (activa) setImagenQR({ token: qr.token, url, blob });
        else URL.revokeObjectURL(url);
      })
      .catch((e: unknown) => {
        if (activa) setErrorImagenQR(e instanceof Error ? e.message : 'No se pudo generar la imagen de la invitación.');
      });

    return () => {
      activa = false;
      if (url) URL.revokeObjectURL(url);
    };
  }, [qr]);

  const imagenLista = qr && imagenQR?.token === qr.token ? imagenQR : null;

  function descargarInvitacion() {
    if (!imagenLista || !qr) return;
    const nombreSeguro = qr.nombre.trim().split(/\s+/)[0]
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .toLowerCase().replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '') || 'participante';
    const telefono = qr.telefono.replace(/\D/g, '') || 'sin-telefono';
    const enlace = document.createElement('a');
    enlace.href = imagenLista.url;
    enlace.download = `${nombreSeguro}-${telefono}.png`;
    document.body.appendChild(enlace);
    enlace.click();
    enlace.remove();
    setMensaje('Invitación navideña PNG descargada. Conserva el archivo: el token no se puede recuperar después.');
  }

  function imprimirInvitacion() {
    if (!imagenLista) return;
    window.print();
  }


  const cargar = useCallback(async () => {
    setCargando(true);
    setError('');
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Tu sesión terminó. Cierra la sesión e ingresa de nuevo.');
      const { data, error: fallo } = await supabase.functions.invoke('bandeja-personal', {
        body: { tipo: pagos ? 'pagos' : 'participantes', pagina, busqueda: filtro },
        headers: { Authorization: `Bearer ${session.access_token}` },
      });
      const respuesta = data as Respuesta | null;
      if (fallo || respuesta?.ok !== true) throw new Error(respuesta?.error || fallo?.message || 'Error de consulta');
      setFilas(respuesta.registros || []);
      setTotal(respuesta.total || 0);
      setLimite(respuesta.limite || 20);
      setLimitado(Boolean(respuesta.limitado));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo cargar la información');
    } finally {
      setCargando(false);
    }
  }, [pagos, pagina, filtro]);

  useEffect(() => { void cargar(); }, [cargar]);
  useEffect(() => {
    void supabase.auth.getUser().then(({ data }) => {
      if (data.user?.email) setUsuario(data.user.email);
    });
  }, []);

  async function procesar(fila: Fila, accion: 'aprobar' | 'rechazar') {
    if (!fila.pago_id || fila.pago_estado !== 'pendiente' || operando) return;
    let motivo = '';
    if (accion === 'rechazar') {
      const respuesta = window.prompt(`Motivo del rechazo para ${fila.nombre} (mínimo 5 caracteres):`);
      if (respuesta === null) return;
      motivo = respuesta.trim();
      if (motivo.length < 5 || motivo.length > 500) { setError('El motivo debe tener entre 5 y 500 caracteres.'); return; }
    } else if (!window.confirm(`¿Confirmas la aprobación del pago de ${fila.nombre} por ${dinero(fila.importe)}?`)) return;

    setOperando(fila.pago_id);
    setMensaje(''); setError(''); setQr(null);
    try {
      // La función SQL verifica auth.uid, que el rol sea validador y el estado pendiente;
      // bloquea la fila para impedir dos aprobaciones y registra la auditoría.
      const { data, error: fallo } = await supabase.rpc('validar_pago_personal', {
        p_pago_id: fila.pago_id,
        p_accion: accion,
        p_motivo: motivo || null,
      });
      if (fallo || !data?.ok) throw new Error(fallo?.message || data?.error || 'No se pudo validar el pago');
      const invitacion = data.invitacion as { token_qr?: string | null } | null;
      if (accion === 'aprobar' && invitacion?.token_qr) {
        setQr({ token: invitacion.token_qr, nombre: fila.nombre, folio: fila.folio, telefono: fila.telefono });
      }
      setMensaje(accion === 'aprobar' ? 'Pago validado. La inscripción quedó confirmada.' : 'Pago rechazado y registrado en auditoría.');
      await cargar();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error al validar el pago');
    } finally {
      setOperando(null);
    }
  }

  async function salir() {
    const { error: fallo } = await supabase.auth.signOut();
    if (fallo) { setError('No se pudo cerrar sesión. Intenta otra vez.'); return; }
    setQr(null);
    onSalir();
  }

  const titulo = pagos ? 'Validación de pagos' : 'Recepción de participantes';
  return (
    <main style={{ minHeight: '100vh', background: '#fff6f9', padding: '24px 16px', color: '#4b3440' }}>
      <style>{`@media print {
        @page { size: A4 portrait; margin: 8mm; }
        body * { visibility: hidden !important; }
        #invitacion-imprimir-validador {
          visibility: visible !important;
          position: fixed !important;
          top: 0 !important;
          left: 50% !important;
          transform: translateX(-50%) !important;
          width: auto !important;
          max-width: 100% !important;
          height: 270mm !important;
          max-height: 270mm !important;
          object-fit: contain !important;
          box-shadow: none !important;
          border: 0 !important;
          margin: 0 !important;
          print-color-adjust: exact;
          -webkit-print-color-adjust: exact;
        }
      }`}</style>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <header style={{ display: 'flex', gap: 18, justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', marginBottom: 25 }}>
          <div>
            <h1 style={{ margin: 0, color: '#a33460' }}>JOYERÍA AMOR</h1>
            <p style={{ color: '#816d78', margin: '6px 0' }}>Evento Anual 2026 · {usuario}</p>
            <strong style={{ display: 'inline-flex', gap: 8, alignItems: 'center', color: '#a33460' }}><ShieldCheck size={17} /> Perfil: {rol}</strong>
          </div>
          <button type="button" style={secundario} onClick={() => void salir()}><LogOut size={16} style={{ verticalAlign: 'middle' }} /> Cerrar sesión</button>
        </header>
        <section style={{ ...tarjeta, marginBottom: 16 }}>
          <h2 style={{ marginTop: 0, color: '#a33460', display: 'flex', gap: 9, alignItems: 'center' }}>
            {pagos ? <ClipboardCheck size={24} /> : <Users size={24} />} {titulo}
          </h2>
          <p style={{ color: '#776a70' }}>
            {pagos
              ? 'Consulta comprobantes y aprueba o rechaza pagos pendientes. Las invitaciones se emiten automáticamente al aprobar.'
              : 'Consulta la lista de inscripciones y su estado. Este perfil no puede validar pagos, emitir invitaciones ni administrar usuarios.'}
          </p>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
            <strong style={{ fontSize: 26, color: '#a33460' }}>{total} <span style={{ fontSize: 14, fontWeight: 400 }}>{pagos ? 'comprobantes' : 'inscripciones'}</span></strong>
            <button type="button" disabled={cargando} style={secundario} onClick={() => void cargar()}><RefreshCw size={15} style={{ verticalAlign: 'middle' }} /> Actualizar</button>
          </div>
          <form onSubmit={(e: FormEvent) => { e.preventDefault(); setPagina(1); setFiltro(busqueda.trim()); }} style={{ display: 'flex', gap: 9, flexWrap: 'wrap', marginTop: 16 }}>
            <input value={busqueda} onChange={e => setBusqueda(e.target.value)} placeholder="Buscar por nombre, folio o WhatsApp" aria-label="Buscar registros" style={{ flex: '1 1 240px', minWidth: 0, padding: 11, border: '1px solid #dbbac8', borderRadius: 10 }} />
            <button type="submit" style={primario}><Search size={16} style={{ verticalAlign: 'middle' }} /> Buscar</button>
          </form>
        </section>

        {error && <p role="alert" style={{ padding: 12, background: '#fff0f2', color: '#982943', borderRadius: 10 }}>{error}</p>}
        {mensaje && <p role="status" style={{ padding: 12, background: '#eaf8f0', color: '#14613f', borderRadius: 10 }}>{mensaje}</p>}
        {limitado && <p style={{ color: '#83591c' }}>La bandeja muestra hasta 500 resultados recientes. Para históricos más grandes se necesita paginación de servidor.</p>}

        {qr && <section style={{ ...tarjeta, border: '2px solid #b4814e', textAlign: 'center', marginBottom: 18 }}>
          <h3 style={{ color: '#a33460' }}>Invitación navideña emitida · {qr.nombre}</h3>
          <p>Folio: {qr.folio}</p>
          {/* El QR real se utiliza para generar el PNG localmente. Nunca se envía a otro servicio. */}
          <div aria-hidden="true" style={{ position: 'absolute', width: 1, height: 1, overflow: 'hidden', clipPath: 'inset(100%)' }}>
            <QRCodeSVG id="qr-validacion-empleado" value={qr.token} size={354} level="H" marginSize={4} />
          </div>
          {imagenLista ? (
            <img
              id="invitacion-imprimir-validador"
              src={imagenLista.url}
              alt={`Invitación de ${qr.nombre}, folio ${qr.folio}`}
              style={{ display: 'block', width: '100%', maxWidth: 445, height: 'auto', margin: '16px auto', borderRadius: 8, boxShadow: '0 10px 25px rgba(52, 28, 37, 0.14)' }}
            />
          ) : (
            <div style={{ margin: '20px auto' }}>
              <QRCodeSVG value={qr.token} size={212} level="H" marginSize={4} />
              <p style={{ color: '#806f77' }}>{errorImagenQR ? 'El QR es válido, pero no se pudo preparar el diseño.' : 'Preparando invitación navideña…'}</p>
            </div>
          )}
          {errorImagenQR && <p role="alert" style={{ color: '#a02940' }}>{errorImagenQR}. Comprueba que estén los archivos en la carpeta public.</p>}
          <p style={{ color: '#8b5436', fontWeight: 700 }}>Guarda o imprime esta invitación antes de cerrar. El código original no se puede recuperar a partir de su hash.</p>
          <div style={{ display: 'flex', justifyContent: 'center', flexWrap: 'wrap', gap: 10 }}>
            <button type="button" style={primario} disabled={!imagenLista} onClick={imprimirInvitacion}><Printer size={16} style={{ verticalAlign: 'middle' }} /> Imprimir invitación</button>
            <button type="button" style={{ ...primario, background: '#176747' }} disabled={!imagenLista} onClick={descargarInvitacion}><Download size={16} style={{ verticalAlign: 'middle' }} /> Descargar PNG</button>
            <button type="button" style={secundario} onClick={() => { void navigator.clipboard.writeText(qr.token).then(() => setMensaje('Código QR copiado'), () => setError('No se pudo copiar el código.')); }}>Copiar código QR</button>
            <button type="button" style={secundario} onClick={() => setQr(null)}>Cerrar QR</button>
          </div>
        </section>}

        <section style={tarjeta}>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ borderCollapse: 'collapse', width: '100%', minWidth: pagos ? 900 : 680, textAlign: 'left' }}>
              <thead style={{ background: '#fff0f5', color: '#a33460' }}>
                <tr>{(pagos ? ['Participante', 'Folio', 'Importe', 'Estado', 'Comprobante', 'Acciones'] : ['Participante', 'Folio', 'Registro', 'Fecha']).map(x => <th key={x} style={{ padding: 12 }}>{x}</th>)}</tr>
              </thead>
              <tbody>
                {filas.map(f => <tr key={f.pago_id || f.registro_id} style={{ borderBottom: '1px solid #f2e3e8' }}>
                  <td style={{ padding: 12 }}><strong>{f.nombre}</strong><div style={{ fontSize: 12, color: '#806f77' }}>{f.telefono}</div></td>
                  <td style={{ padding: 12 }}>{f.folio}</td>
                  {pagos ? <>
                    <td style={{ padding: 12 }}>{dinero(f.importe)}<div style={{ fontSize: 12 }}>{f.referencia || 'Sin referencia'}</div></td>
                    <td style={{ padding: 12 }}>{f.pago_estado}</td>
                    <td style={{ padding: 12 }}>{f.comprobante_url ? <a href={f.comprobante_url} target="_blank" rel="noreferrer">Ver comprobante</a> : 'Sin archivo'}</td>
                    <td style={{ padding: 12 }}>
                      {f.pago_estado === 'pendiente' ? <div style={{ display: 'flex', gap: 8 }}>
                        <button type="button" style={{ ...primario, background: '#176747' }} disabled={Boolean(operando)} onClick={() => void procesar(f, 'aprobar')}>Aprobar</button>
                        <button type="button" style={{ ...secundario, color: '#a02940' }} disabled={Boolean(operando)} onClick={() => void procesar(f, 'rechazar')}>Rechazar</button>
                      </div> : <span style={{ color: '#856344' }}>En revisión; no editable</span>}
                    </td>
                  </> : <><td style={{ padding: 12 }}>{f.registro_estado}{f.exento_pago ? ' · Cortesía' : ''}</td><td style={{ padding: 12 }}>{fecha(f.fecha)}</td></>}
                </tr>)}
              </tbody>
            </table>
          </div>
          {!cargando && !error && filas.length === 0 && <p style={{ textAlign: 'center', padding: 20, color: '#816e75' }}>No hay resultados para esta búsqueda.</p>}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 20, gap: 10 }}>
            <button type="button" disabled={pagina <= 1 || cargando} style={secundario} onClick={() => setPagina(p => p - 1)}><ChevronLeft size={15} style={{ verticalAlign: 'middle' }} /> Anterior</button>
            <span>Página {pagina} de {Math.max(1, Math.ceil(total / limite))}</span>
            <button type="button" disabled={pagina * limite >= total || cargando} style={secundario} onClick={() => setPagina(p => p + 1)}>Siguiente <ChevronRight size={15} style={{ verticalAlign: 'middle' }} /></button>
          </div>
        </section>
      </div>
    </main>
  );
}
