import { procesarUno, type Cola, type Contexto, type Trabajo, type Transporte } from './whatsapp-motor.ts';

export const ENSAYO_ID='2bba9e9e-8751-49df-b1bb-17a82c7120d3';
export const TELEFONO_HASH='e52c6229f3e0841ae55fd4f5ca575719a5c4a989ba9cf5b8151f6c953e30b8e9';
export const NUMERO_PRUEBA_META='1302305149644004';
const FOTO='3dc92160-79af-4bf7-b770-263038e88900/pruebas/'+ENSAYO_ID+'.png';
const JSON_HEADERS={'Content-Type':'application/json','Cache-Control':'no-store'};
const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers:JSON_HEADERS});
export type DependenciasEnsayo={
 env:(name:string)=>string|undefined;
 identidad:(bearer:string)=>Promise<string|null>;
 rpc:(admin:string,accion:string,datos?:Record<string,unknown>)=>Promise<unknown>;
 subirFoto:(path:string)=>Promise<void>;
 imagen:(contexto:Contexto)=>Promise<Uint8Array>;
 transporte:()=>Transporte;
 validarMeta:()=>Promise<{ok:boolean;codigo?:string}>;
};

/** Administrative JWT is validated again here; SQL independently checks active Chiapas assignment. */
export function manejarEnsayo(d:DependenciasEnsayo){return async(req:Request):Promise<Response>=>{
 const origin=req.headers.get('origin');
 if(origin&&!['http://localhost:5173','http://127.0.0.1:5173'].includes(origin))return reply(403,{ok:false});
 if(req.method!=='POST')return reply(405,{ok:false});
 const bearer=req.headers.get('authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
 if(!bearer)return reply(401,{ok:false});
 try{
  const admin=await d.identidad(bearer);if(!admin)return reply(401,{ok:false});
  if(d.env('WHATSAPP_ENSAYO_PLATAFORMA_HABILITADO')!=='true')return reply(503,{ok:false,error:'ensayo_deshabilitado'});
  // The general worker stays OFF. This route cannot be used during general dispatch.
  if(d.env('WHATSAPP_ENVIOS_HABILITADOS')==='true'||d.env('WHATSAPP_MODO')==='real')
   return reply(409,{ok:false,error:'cola_general_debe_estar_apagada'});
  const raw=await req.text();if(raw.length>1024)return reply(413,{ok:false});
  let body;try{body=JSON.parse(raw);}catch{return reply(400,{ok:false});}
  if(!body||typeof body!=='object'||Array.isArray(body)||Object.keys(body).some(k=>!['accion','confirmar'].includes(k))||
   !['crear','confirmar','procesar','estado','cerrar'].includes(body.accion)||
   (body.accion!=='estado'&&body.confirmar!==true))return reply(400,{ok:false,error:'confirmacion_requerida'});
  // Read-only authorization preflight BEFORE Storage or provider calls, including create.
  await d.rpc(admin,'permiso');
  const telefono=d.env('WHATSAPP_TEST_DESTINATARIO')?.trim()??'';
  const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(telefono)))).map(n=>n.toString(16).padStart(2,'0')).join('');
  if(digest!==TELEFONO_HASH||d.env('META_WHATSAPP_PHONE_NUMBER_ID')!==NUMERO_PRUEBA_META)
   return reply(503,{ok:false,error:'solo_emisor_y_destinatario_de_prueba'});
  if(body.accion==='crear'){
   await d.subirFoto(FOTO);
   const resultado=await d.rpc(admin,'crear',{telefono,foto_path:FOTO});
   return reply(200,resultado);
  }
  if(body.accion!=='procesar')return reply(200,await d.rpc(admin,body.accion));
  // Preflight credentials BEFORE reserving the sole attempt. Never exposes credentials in responses.
  if(!d.env('META_WHATSAPP_TOKEN')?.trim()||!/^v[0-9]{2}\.0$/.test(d.env('META_GRAPH_VERSION')??''))
   return reply(503,{ok:false,error:'configuracion_meta_incompleta'});
  const preflight=await d.validarMeta();
  if(!preflight.ok)return reply(503,{ok:false,error:preflight.codigo??'meta_no_disponible'});
  const transporte=d.transporte();
  let trabajo:Trabajo|null=null;
  const rpc=(accion:string,datos:Record<string,unknown>={})=>d.rpc(admin,accion,datos);
  const args=(t:Trabajo)=>({reserva_id:t.reserva_id,invitacion_id:t.invitacion_id});
  const cola:Cola={
   reservar:async()=>{trabajo=await rpc('reservar') as Trabajo|null;return trabajo;},
   contexto:async()=>await rpc('contexto',args(trabajo!)) as Contexto,
   autorizar:async t=>await rpc('autorizar',args(t)) as Contexto,
   guardarMedia:async(t,media)=>await rpc('medio',{...args(t),media_id:media})===true,
   marcarMediaEliminado:async(t,media)=>await rpc('medio_eliminado',{...args(t),media_id:media})===true,
   finalizar:async(t,fase,codigo,message_id)=>await rpc('finalizar',{...args(t),fase,codigo,message_id})===true,
  };
  // Only the registry fixture can be returned by SQL. Reuse the actual engine, renderer and transport.
  const resultado=await procesarUno({modo:'real',habilitado:true,plantillaAprobada:true,numeroConfigurado:true,
   credencialPermanente:true,pruebaAutorizada:true,produccionAutorizada:true},cola,d.imagen,transporte);
  return reply(200,{ok:true,...resultado,ensayo_id:ENSAYO_ID});
 }catch{return reply(503,{ok:false,error:'ensayo_no_disponible'});}
};}
