import { esChiapas, eventoActual } from '../lib/evento';
import { invocarEvento } from '../lib/evento';
import { useEffect, useRef, useState } from 'react';
import { Camera, CheckCircle2, ScanLine, ShieldAlert } from 'lucide-react';
import { supabase } from '../lib/supabase';

type Ficha = {
  ok: boolean; estado: string; folio?: string; registro_id?: string;
  ingresado_at?: string | null; nombre?: string; asesor?: string;
  telefono?: string; foto_url?: string | null;
};
type Detector = { detect: (source: HTMLVideoElement) => Promise<Array<{rawValue:string}>> };
const DetectorClass = (globalThis as typeof globalThis & {BarcodeDetector?: new (options: {formats:string[]}) => Detector}).BarcodeDetector;
const card: React.CSSProperties = {background:'#fff',border:'1px solid #efd5df',borderRadius:18,padding:22,marginBottom:16};
const btn: React.CSSProperties = {background:'#a33460',color:'white',border:0,borderRadius:10,padding:'13px 18px',cursor:'pointer',fontWeight:700};

export default function ControlAcceso({ eventoId = esChiapas ? eventoActual.id : undefined }: { eventoId?: string }) {
  const [entrada,setEntrada] = useState('');
  const [token,setToken] = useState('');
  const [ficha,setFicha] = useState<Ficha|null>(null);
  const [mensaje,setMensaje] = useState('');
  const [cargando,setCargando] = useState(false);
  const [camara,setCamara] = useState(false);
  const video = useRef<HTMLVideoElement>(null);
  const stream = useRef<MediaStream|null>(null);
  const ultimo = useRef('');
  const procesando = useRef(false);

  async function consultar(valor:string) {
    const limpio=valor.trim();
    if (!limpio || procesando.current) return;
    procesando.current=true;
    setCargando(true); setMensaje(''); setFicha(null); setToken('');
    try {
      const funcionConsulta = eventoId
         ? 'consultar-acceso-evento'
         : 'consultar-acceso';
       const cuerpoConsulta = eventoId
         ? {token:limpio,evento_id:eventoId}
         : {token:limpio};
       const {data,error}=await invocarEvento(
         funcionConsulta,
         {body:cuerpoConsulta}
       );
      if(error || !data?.ok) throw new Error(data?.error || error?.message || 'No se pudo validar el QR');
      setFicha(data.ficha as Ficha); setToken(limpio);
      if(data.ficha.estado !== 'autorizable') setMensaje(({ya_ingreso:'Esta participante ya ingresó',revocada:'Invitación revocada',no_confirmado:'Inscripción no confirmada',qr_invalido:'QR inválido'} as Record<string,string>)[data.ficha.estado] || 'Entrada no autorizada');
    } catch(e) {setMensaje(e instanceof Error?e.message:'Error de validación');}
    finally {setCargando(false);procesando.current=false;setEntrada('');}
  }
  async function autorizar() {
    if(!token || ficha?.estado!=='autorizable' || cargando) return;
    setCargando(true);
    try {
      const {data,error}=eventoId
         ? await supabase.rpc(
             'registrar_entrada_qr_evento',
             {p_token:token,p_evento_id:eventoId}
           )
         : await supabase.rpc(
             'registrar_entrada_qr',
             {p_token:token}
           );
      if(error) throw error;
      if(data?.ok && data?.estado==='ingreso_registrado') {
        setFicha(v=>v?{...v,estado:'ya_ingreso',ingresado_at:data.ingresado_at}:v);
        setMensaje('Entrada registrada correctamente');
      } else {setMensaje(data?.estado==='ya_ingreso'?'Esta participante ya ingresó':`No autorizado: ${data?.estado || 'Error'}`);}
    } catch(e) {setMensaje(e instanceof Error?e.message:'No se pudo registrar entrada');}
    finally {setCargando(false);}
  }
  useEffect(()=>{
    if(!camara) return;
    let cancelado=false;
    let raf=0;
    let detector:Detector|null=null;
    let ocupado=false;
    async function iniciar() {
      if(!DetectorClass) {setMensaje('Este navegador no admite lectura QR por cámara. Utiliza Chrome compatible o lector USB.');setCamara(false);return;}
      try {
        const s=await navigator.mediaDevices.getUserMedia({video:{facingMode:'environment'},audio:false});
        if(cancelado){s.getTracks().forEach(t=>t.stop());return;}
        stream.current=s;
        if(video.current){video.current.srcObject=s;await video.current.play();}
        detector=new DetectorClass({formats:['qr_code']});
        async function ciclo() {
          if(cancelado) return;
          if(!ocupado && video.current?.readyState===4 && detector) {
            ocupado=true;
            try {const codigos=await detector.detect(video.current);const t=codigos[0]?.rawValue;
              if(t && t!==ultimo.current){ultimo.current=t;void consultar(t);setCamara(false);return;}
            } catch {/* Continuar escaneando */} finally {ocupado=false;}
          }
          raf=requestAnimationFrame(ciclo);
        }
        raf=requestAnimationFrame(ciclo);
      } catch {setMensaje('No se pudo abrir la cámara. Revisa permisos y conexión HTTPS.');setCamara(false);}
    }
    void iniciar();
    return ()=>{cancelado=true;cancelAnimationFrame(raf);stream.current?.getTracks().forEach(t=>t.stop());stream.current=null;};
  // El lector se detiene al detectar un código.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  },[camara]);
  return <section style={{maxWidth:760,margin:'24px auto',padding:16,color:'#48303a'}}>
    <h2 style={{color:'#a33460'}}>Control de acceso · JOYERÍA AMOR</h2>
    <p>Escanea la invitación, verifica la fotografía y confirma la entrada.</p>
    <div style={card}>
      <form onSubmit={e=>{e.preventDefault();void consultar(entrada);}} style={{display:'flex',gap:10,flexWrap:'wrap'}}>
        <input autoFocus aria-label="Código QR" placeholder="Escanea con lector USB o pega el token" value={entrada} onChange={e=>setEntrada(e.target.value)} style={{flex:'1 1 240px',padding:12,border:'1px solid #d8b8c5',borderRadius:10}} />
        <button disabled={cargando} style={btn}><ScanLine size={17} style={{verticalAlign:'middle'}}/> Consultar</button>
      </form>
      <button type="button" onClick={()=>setCamara(v=>!v)} style={{...btn,marginTop:12,background:'#785269'}}><Camera size={17} style={{verticalAlign:'middle'}}/> {camara?'Cerrar cámara':'Escanear con cámara'}</button>
      {camara && <video ref={video} muted playsInline style={{display:'block',width:'100%',maxHeight:340,marginTop:14,borderRadius:12,background:'#222'}}/>}
    </div>
    {cargando && <p>Procesando...</p>}
    {mensaje && <div role="status" style={{...card,background:ficha?.estado==='ya_ingreso'?'#fff4e7':'#fff5f8',fontWeight:700}}>{mensaje}</div>}
    {ficha && <div style={card}>
      <div style={{display:'flex',alignItems:'center',gap:20,flexWrap:'wrap'}}>
        {ficha.foto_url ? <img src={ficha.foto_url} alt="Fotografía registrada de la participante" style={{width:160,height:180,objectFit:'cover',borderRadius:12}}/> : <div style={{width:160,height:180,display:'grid',placeItems:'center',background:'#f5e9ed',borderRadius:12}}>Sin fotografía</div>}
        <div><h2>{ficha.nombre || 'Participante'}</h2><p><b>Folio:</b> {ficha.folio || 'Sin folio'}</p><p><b>Asesor:</b> {ficha.asesor || 'No asignado'}</p><p><b>Teléfono:</b> {ficha.telefono || 'No disponible'}</p><p><b>Estado:</b> {ficha.estado}</p>{ficha.ingresado_at && <p><b>Ingreso:</b> {new Date(ficha.ingresado_at).toLocaleString('es-MX')}</p>}</div>
      </div>
      {ficha.estado==='autorizable' ? <button type="button" disabled={cargando} onClick={()=>void autorizar()} style={{...btn,background:'#176c49',width:'100%',marginTop:18}}><CheckCircle2 size={18} style={{verticalAlign:'middle'}}/> Autorizar entrada</button> : <p style={{color:'#9a2944',fontWeight:700}}><ShieldAlert size={18} style={{verticalAlign:'middle'}}/> No autorizar entrada</p>}
    </div>}
  </section>;
}
