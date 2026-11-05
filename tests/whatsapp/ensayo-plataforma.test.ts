import {manejarEnsayo,NUMERO_PRUEBA_META} from '../../supabase/functions/_shared/whatsapp-ensayo-plataforma.ts';
import type {Contexto} from '../../supabase/functions/_shared/whatsapp-motor.ts';
const assert=(value:unknown)=>{if(!value)throw Error('Comprobación de aislamiento fallida');};
const telefono=Deno.env.get('FIESTA_TEST_DESTINATARIO');
if(!telefono)throw Error('Falta destinatario autorizado de ensayo local');
const admin='a1111111-1111-4111-8111-111111111111',iid='b1111111-1111-4111-8111-111111111111';
function fixture(){
 const config:Record<string,string>={WHATSAPP_ENSAYO_PLATAFORMA_HABILITADO:'true',WHATSAPP_ENVIOS_HABILITADOS:'false',WHATSAPP_MODO:'simulacion',WHATSAPP_TEST_DESTINATARIO:telefono!,META_WHATSAPP_PHONE_NUMBER_ID:NUMERO_PRUEBA_META,META_WHATSAPP_TOKEN:'ficticio-no-real',META_GRAPH_VERSION:'v25.0'};
 const calls:string[]=[];let identidad:string|null=admin,permiso=true,reservado=false,preflight=true;
 const contexto:Contexto={elegible:true,invitacion_id:iid,registro_id:crypto.randomUUID(),evento_id:'3dc92160-79af-4bf7-b770-263038e88900',telefono:telefono!,token_qr:'token-ficticio-ensayo-no-acceso',folio:'PRUEBA',participante:'PRUEBA',evento:'ENSAYO',fecha:'19 diciembre 2026',lugar:'BIANCO',recepcion:'Por confirmar'};
 const handle=manejarEnsayo({env:n=>config[n],identidad:async()=>identidad,
  rpc:async(_admin,accion)=>{calls.push('rpc:'+accion);if(accion==='permiso'&&!permiso)throw Error('sin_asignacion');
   if(accion==='reservar'){if(reservado)return null;reservado=true;return{id:crypto.randomUUID(),invitacion_id:iid,reserva_id:crypto.randomUUID()};}
   if(['contexto','autorizar'].includes(accion))return contexto;
   if(['medio','medio_eliminado','finalizar'].includes(accion))return true;
   return{ok:true,es_prueba:true};},
  subirFoto:async()=>{calls.push('storage');},imagen:async()=>{calls.push('png');return new Uint8Array([137,80,78,71]);},
  validarMeta:async()=>{calls.push('meta:preflight');return{ok:preflight,codigo:'fixture_preflight'};},
  transporte:()=>({cargar:async()=>{calls.push('meta:media');return'123';},enviar:async c=>{assert(c.telefono===telefono);calls.push('meta:mensaje');return{id:'wamid.fixture'};},eliminar:async()=>{calls.push('meta:eliminar');}}),
 });
 const req=(body:unknown,headers:Record<string,string>={Authorization:'Bearer fixture'},method='POST')=>handle(new Request('http://localhost/ensayo',{method,headers,body:method==='POST'?JSON.stringify(body):undefined}));
 return{config,calls,req,setIdentidad:(v:string|null)=>identidad=v,setPermiso:(v:boolean)=>permiso=v,setPreflight:(v:boolean)=>preflight=v};
}
Deno.test('sin JWT ni método válido no hay efectos',async()=>{const f=fixture();assert((await f.req({},{})).status===401);assert((await f.req({},undefined,'GET')).status===405);assert(f.calls.length===0);});
Deno.test('JWT no validado no autoriza',async()=>{const f=fixture();f.setIdentidad(null);assert((await f.req({accion:'crear',confirmar:true})).status===401);assert(f.calls.length===0);});
Deno.test('ensayo deshabilitado por defecto',async()=>{const f=fixture();delete f.config.WHATSAPP_ENSAYO_PLATAFORMA_HABILITADO;assert((await f.req({accion:'crear',confirmar:true})).status===503);assert(f.calls.length===0);});
Deno.test('cola general real impide ensayo',async()=>{for(const key of ['WHATSAPP_ENVIOS_HABILITADOS','WHATSAPP_MODO']){const f=fixture();f.config[key]=key.endsWith('MODO')?'real':'true';assert((await f.req({accion:'crear',confirmar:true})).status===409);assert(f.calls.length===0);}});
Deno.test('origen externo rechazado',async()=>{const f=fixture();assert((await f.req({accion:'estado'},{Authorization:'Bearer fixture',Origin:'https://ajeno.example'})).status===403);assert(f.calls.length===0);});
Deno.test('IDs, destinatarios, roles y campos cliente no pueden inyectarse',async()=>{for(const key of ['evento_id','registro_id','admin_id','telefono','rol','modo']){const f=fixture();assert((await f.req({accion:'crear',confirmar:true,[key]:'manipulado'})).status===400);assert(f.calls.length===0);}});
Deno.test('operaciones requieren confirmación explícita',async()=>{const f=fixture();for(const accion of ['crear','confirmar','procesar','cerrar'])assert((await f.req({accion})).status===400);assert(f.calls.length===0);});
Deno.test('asignación se revisa antes de Storage',async()=>{const f=fixture();f.setPermiso(false);assert((await f.req({accion:'crear',confirmar:true})).status===503);assert(!f.calls.includes('storage'));});
Deno.test('otro destinatario o número oficial no pueden usarse',async()=>{for(const key of ['WHATSAPP_TEST_DESTINATARIO','META_WHATSAPP_PHONE_NUMBER_ID']){const f=fixture();f.config[key]='otro';assert((await f.req({accion:'crear',confirmar:true})).status===503);assert(!f.calls.includes('storage'));}});
Deno.test('crear solo almacena la foto y llama al alta controlada',async()=>{const f=fixture();assert((await f.req({accion:'crear',confirmar:true})).status===200);assert(f.calls.join(',')==='rpc:permiso,storage,rpc:crear');});
Deno.test('preflight Meta fallido no consume el único intento',async()=>{const f=fixture();f.setPreflight(false);assert((await f.req({accion:'procesar',confirmar:true})).status===503);assert(!f.calls.includes('rpc:reservar'));assert(!f.calls.includes('meta:mensaje'));});
Deno.test('motor real reutilizado genera PNG, carga y envía una sola vez',async()=>{const f=fixture();const r=await f.req({accion:'procesar',confirmar:true});const j=await r.json();assert(j.estado==='aceptado');assert(!JSON.stringify(j).includes('token-ficticio'));assert(f.calls.filter(c=>c==='meta:mensaje').length===1);assert(f.calls.indexOf('rpc:autorizar')>f.calls.indexOf('meta:media'));await f.req({accion:'procesar',confirmar:true});assert(f.calls.filter(c=>c==='meta:mensaje').length===1);});
