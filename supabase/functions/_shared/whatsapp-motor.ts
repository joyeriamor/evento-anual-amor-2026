export const PLANTILLA='amor_invitacion_confirmada_v1';
export type Trabajo={id:string;invitacion_id:string;reserva_id:string};
export type Contexto={elegible:true;invitacion_id:string;registro_id:string;evento_id:string;
 token_qr:string;telefono:string;folio:string;participante:string;evento:string;fecha:string;recepcion:string;lugar:string};
export type Revision=Contexto|{elegible:false;codigo:string};
export type Fase='aceptado'|'fallido'|'incierto'|'simulado'|'sin_consentimiento'|'cancelado';
export interface Cola {
 reservar(modo:'simulacion'|'real'):Promise<Trabajo|null>;
 contexto(id:string):Promise<Revision>;
 autorizar(t:Trabajo):Promise<Revision>;
 guardarMedia(t:Trabajo,media:string):Promise<boolean>;
 marcarMediaEliminado(t:Trabajo,media:string):Promise<boolean>;
 finalizar(t:Trabajo,fase:Fase,codigo?:string,mensaje?:string):Promise<boolean>;
}
export interface Transporte {
 cargar(png:Uint8Array):Promise<string>;
 enviar(c:Contexto,media:string):Promise<{id:string}>;
 eliminar(media:string):Promise<void>;
}
export type Configuracion={modo:'simulacion'|'real';habilitado:boolean;plantillaAprobada:boolean;
 numeroConfigurado:boolean;credencialPermanente:boolean;pruebaAutorizada:boolean;produccionAutorizada:boolean};
export function permiteReal(c:Configuracion):boolean {
 return c.modo==='real' && c.habilitado && c.plantillaAprobada && c.numeroConfigurado &&
 c.credencialPermanente && c.pruebaAutorizada && c.produccionAutorizada;
}
function verificar(c:Revision,id:string):c is Contexto {
 return c.elegible===true && c.invitacion_id===id &&
 ['43e67bda-d19d-4c0e-a639-e85f2d62f294','3dc92160-79af-4bf7-b770-263038e88900'].includes(c.evento_id) &&
 /^52[1-9][0-9]{9}$/.test(c.telefono) && c.token_qr.length>=16 && c.token_qr.length<=1024;
}
/** One job per invocation; no automatic retry after any message request starts. */
export async function procesarUno(config:Configuracion,cola:Cola,imagen:(c:Contexto)=>Promise<Uint8Array>,meta:Transporte) {
 if(config.modo==='real' && !permiteReal(config)) return {estado:'deshabilitado'};
 const t=await cola.reservar(config.modo);
 if(!t)return {estado:'sin_trabajos'};
 let media:string|undefined,solicitudIniciada=false;
 try {
  const c=await cola.contexto(t.invitacion_id);
  if(!verificar(c,t.invitacion_id)) {
   const fase=c.elegible===false && c.codigo==='sin_consentimiento'?'sin_consentimiento':'cancelado';
   await cola.finalizar(t,fase,'no_elegible');return {estado:fase};
  }
  const png=await imagen(c);
  if(config.modo==='real'){
   media=await meta.cargar(png);
   if(!await cola.guardarMedia(t,media))throw new Error('media_no_persistido');
  }
  // After image generation/upload, check consent, QR and record again before dispatch.
  const final=await cola.autorizar(t);
  if(!verificar(final,t.invitacion_id) || final.token_qr!==c.token_qr || final.telefono!==c.telefono ||
    final.participante!==c.participante || final.folio!==c.folio || final.fecha!==c.fecha ||
    final.lugar!==c.lugar || final.recepcion!==c.recepcion) {
   const fase=final.elegible===false && final.codigo==='sin_consentimiento'?'sin_consentimiento':'cancelado';
   await cola.finalizar(t,fase,'contexto_cambio');return {estado:fase};
  }
  if(config.modo==='simulacion') {
   await cola.finalizar(t,'simulado');return {estado:'simulado'};
  }
  if(!media)throw new Error('media_ausente');
  solicitudIniciada=true;
  const respuesta=await meta.enviar(final,media);
  if(!respuesta.id || respuesta.id.length>255)throw new Error('respuesta_invalida');
  const guardado=await cola.finalizar(t,'aceptado',undefined,respuesta.id);
  if(!guardado)return {estado:'incierto'};
  // Do not delete accepted media before Meta has delivered it; retention cleanup is separate.
  media=undefined;
  return {estado:'aceptado'};
 } catch {
  const fase=solicitudIniciada?'incierto':'fallido';
  // Never store provider bodies, exceptions, QR, phone numbers or credentials.
  await cola.finalizar(t,fase,solicitudIniciada?'resultado_meta_incierto':'preparacion_fallida').catch(()=>false);
  return {estado:fase};
 } finally {
  // An uncertain submission may still deliver: retain its media, never retry it automatically.
  if(media && !solicitudIniciada){
   try{await meta.eliminar(media);await cola.marcarMediaEliminado(t,media);}catch{/* Retain metadata for explicit cleanup; never resend here. */}
  }
 }
}
export function cuerpoPlantilla(c:Contexto,mediaId:string) {
 return {messaging_product:'whatsapp',to:c.telefono,type:'template',template:{name:PLANTILLA,
 language:{code:'es_MX'},components:[{type:'header',parameters:[{type:'image',image:{id:mediaId}}]},
 {type:'body',parameters:[c.participante,c.evento,c.fecha,c.recepcion,c.lugar].map(text=>({type:'text',text}))}]}};
}

export type Limpieza={id:string;reserva_id:string;media_id:string};
export interface ColaLimpieza{reservar():Promise<Limpieza|null>;finalizar(t:Limpieza):Promise<boolean>;}
export async function limpiarUno(cola:ColaLimpieza,meta:Transporte){
 const t=await cola.reservar();if(!t)return{estado:'sin_medios'};
 try{await meta.eliminar(t.media_id);return{estado:await cola.finalizar(t)?'medio_eliminado':'limpieza_por_conciliar'};}
 catch{return{estado:'limpieza_fallida'};}
}
