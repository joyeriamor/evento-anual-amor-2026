import { useCallback,useEffect,useState } from 'react';
import { invocarEvento } from '../lib/evento';
type Fila={id:string|null;folio:string;estado:string;intentos:number|null;puede_reintentar:boolean;ultimo_error_codigo:string|null};
const etiquetas:Record<string,string>={pendiente:'Pendiente de envío',procesando:'En proceso',aceptado:'Aceptado por Meta',
 entregado:'Entregado',leido:'Leído',fallido:'Fallido',incierto:'Resultado incierto · requiere revisión',
 sin_consentimiento:'Sin consentimiento',cancelado:'Cancelado',simulado:'Simulación completada',no_preparado:'No preparado'};
export default function WhatsAppAdmin(){
 const [filas,setFilas]=useState<Fila[]>([]),[pagina,setPagina]=useState(1),[error,setError]=useState(''),[ocupado,setOcupado]=useState(false);
 const cargar=useCallback(async()=>{
  setOcupado(true);setError('');
  try{const r=await invocarEvento('whatsapp-administrar',{body:{accion:'listar',pagina}});
   if(r.error||!r.data?.ok)throw new Error('No fue posible consultar el estado de WhatsApp');
   setFilas(r.data.filas);
  }catch(e){setFilas([]);setError(e instanceof Error?e.message:'Error de consulta');}finally{setOcupado(false);}
 },[pagina]);
 // eslint-disable-next-line react-hooks/set-state-in-effect -- Consulta externa al cambiar de página.
 useEffect(()=>{void cargar();},[cargar]);
 async function reintentar(id:string){
  if(ocupado)return;setOcupado(true);setError('');
  try{const r=await invocarEvento('whatsapp-administrar',{body:{accion:'reintentar',envio_id:id}});
   if(r.error||!r.data?.ok)throw new Error('El envío no admite reintento');await cargar();
  }catch(e){setError(e instanceof Error?e.message:'No fue posible reintentar');}finally{setOcupado(false);}
 }
 return <section aria-label="Invitaciones por WhatsApp"><h2>Invitaciones por WhatsApp</h2>
  <p>“Aceptado por Meta” no confirma entrega. Los resultados inciertos requieren revisión y no admiten reintento automático.</p>
  {error&&<p role="alert">{error}</p>}<button disabled={ocupado} onClick={()=>void cargar()}>Actualizar WhatsApp</button>
  <div style={{overflowX:'auto'}}><table><thead><tr><th>Folio</th><th>Estado</th><th>Intentos</th><th>Acción</th></tr></thead>
  <tbody>{filas.map((f,i)=><tr key={f.id??`${f.folio}-${i}`}><td>{f.folio}</td><td>{etiquetas[f.estado]??'Requiere revisión'}</td>
  <td>{f.intentos??0}</td><td>{f.puede_reintentar&&f.id&&<button disabled={ocupado} onClick={()=>void reintentar(f.id!)}>Reintentar preparación</button>}</td></tr>)}</tbody></table></div>
  {!filas.length&&!ocupado&&!error&&<p>No hay inscripciones confirmadas en esta página.</p>}
  <button disabled={ocupado||pagina===1} onClick={()=>setPagina(p=>p-1)}>Anterior</button><span> Página {pagina} </span>
  <button disabled={ocupado||filas.length<50} onClick={()=>setPagina(p=>p+1)}>Siguiente</button>
 </section>;
}
