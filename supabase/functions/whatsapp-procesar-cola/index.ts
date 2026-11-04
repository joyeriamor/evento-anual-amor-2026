import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { procesarUno,permiteReal,limpiarUno,type Configuracion,type Cola,type Revision,type Trabajo,type Transporte } from '../_shared/whatsapp-motor.ts';
import { transporteMeta } from '../_shared/whatsapp-meta.ts';
import { generarImagen } from '../_shared/whatsapp-imagen.ts';
const responder=(estado:number,body:unknown)=>new Response(JSON.stringify(body),{status:estado,
 headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
// Backend-only credential, independent of administrator JWTs. Never expose in a browser.
async function igual(a:string,b:string) {
 const enc=new TextEncoder();
 const [x,y]=await Promise.all([a,b].map(v=>crypto.subtle.digest('SHA-256',enc.encode(v))));
 const xx=new Uint8Array(x),yy=new Uint8Array(y);let d=0;for(let i=0;i<xx.length;i++)d|=xx[i]^yy[i];return d===0;
}
Deno.serve(async req=>{
 if(req.method!=='POST')return responder(405,{ok:false});
 if(req.headers.has('origin'))return responder(403,{ok:false});
 const esperado=Deno.env.get('WHATSAPP_WORKER_SECRET');
 if(!esperado || esperado.length<32 || !await igual(req.headers.get('x-whatsapp-worker-secret')??'',esperado))
  return responder(401,{ok:false});
 // Mode is server configuration, never a request parameter.
 const flag=(n:string)=>Deno.env.get(n)==='true';
 const config:Configuracion={modo:Deno.env.get('WHATSAPP_MODO')==='real'?'real':'simulacion',
 habilitado:flag('WHATSAPP_ENVIOS_HABILITADOS'),plantillaAprobada:flag('WHATSAPP_PLANTILLA_APROBADA'),
 numeroConfigurado:flag('WHATSAPP_NUMERO_CONFIGURADO'),credencialPermanente:flag('WHATSAPP_CREDENCIAL_PERMANENTE'),
 pruebaAutorizada:flag('WHATSAPP_PRUEBA_MANUAL_AUTORIZADA'),produccionAutorizada:flag('WHATSAPP_PRODUCCION_AUTORIZADA')};
 try {
  const url=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if(!url||!key)return responder(503,{ok:false});
  const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  async function rpc(nombre:string,args:Record<string,unknown>) {
   const r=await db.rpc(nombre,args);if(r.error)throw new Error('cola_no_disponible');return r.data;
  }
  const cola:Cola={
   reservar:async modo=>await rpc('whatsapp_reservar_interno',{p_modo:modo}) as Trabajo|null,
   guardarMedia:async(t,media)=>await rpc('whatsapp_guardar_medio_interno',{p_id:t.id,p_reserva:t.reserva_id,p_media:media})===true,
   marcarMediaEliminado:async(t,media)=>await rpc('whatsapp_marcar_medio_eliminado_interno',{p_id:t.id,p_reserva:t.reserva_id,p_media:media})===true,
   contexto:async id=>await rpc('whatsapp_contexto_interno',{p_invitacion_id:id}) as Revision,
   autorizar:async t=>await rpc('whatsapp_autorizar_salida_interno',{p_id:t.id,p_reserva:t.reserva_id}) as Revision,
   finalizar:async(t,fase,codigo,mensaje)=>await rpc('whatsapp_finalizar_interno',{
    p_id:t.id,p_reserva:t.reserva_id,p_fase:fase,p_codigo:codigo??null,p_message_id:mensaje??null})===true,
  };
  const tarea=req.headers.get('x-whatsapp-tarea')??'procesar';
  if(!['procesar','limpiar'].includes(tarea))return responder(400,{ok:false});
  if(tarea==='limpiar'){
   if(config.modo!=='real'||!flag('WHATSAPP_LIMPIEZA_HABILITADA')||!config.produccionAutorizada)return responder(200,{ok:true,estado:'limpieza_deshabilitada'});
   const transporte=transporteMeta(Deno.env.get('META_WHATSAPP_TOKEN')??'',Deno.env.get('META_WHATSAPP_PHONE_NUMBER_ID')??'',Deno.env.get('META_GRAPH_VERSION')??'');
   const resultado=await limpiarUno({
    reservar:async()=>await rpc('whatsapp_reservar_limpieza_interno',{}),
    finalizar:async t=>await rpc('whatsapp_finalizar_limpieza_interno',{p_id:t.id,p_reserva:t.reserva_id,p_media:t.media_id})===true,
   },transporte);
   return responder(200,{ok:true,...resultado});
  }
  if(config.modo==='real'&&!permiteReal(config))return responder(200,{ok:true,estado:'deshabilitado'});
  // In simulation there is no network transport to Meta, even if credentials exist.
  const prohibido=async()=>{throw new Error('meta_deshabilitado')};
  const meta:Transporte=config.modo==='real'?transporteMeta(Deno.env.get('META_WHATSAPP_TOKEN')??'',
   Deno.env.get('META_WHATSAPP_PHONE_NUMBER_ID')??'',Deno.env.get('META_GRAPH_VERSION')??''):
   {cargar:prohibido,enviar:prohibido,eliminar:prohibido};
  const resultado=await procesarUno(config,cola,generarImagen,meta);
  return responder(200,{ok:true,...resultado});
 }catch{return responder(503,{ok:false,error:'No fue posible procesar la cola'});}
});
