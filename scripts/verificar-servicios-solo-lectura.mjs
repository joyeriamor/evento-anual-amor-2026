// Real HTTP probes are opt-in. Fixed project, GET only, no business endpoints.
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
export const PROJECT_URL='https://rkjlqxxmxbiciuhtpnpf.supabase.co';
const CHIAPAS='3dc92160-79af-4bf7-b770-263038e88900';
export function validarConfiguracion(url,key){
 if(url!==PROJECT_URL)throw Error('Destino diferente del proyecto autorizado.');
 let publishable=typeof key==='string'&&/^sb_publishable_[A-Za-z0-9_-]+$/.test(key);
 if(!publishable&&typeof key==='string'){
  try{const claims=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString());publishable=claims.role==='anon';}catch{publishable=false;}
 }
 if(!publishable)throw Error('Solo se admite clave publicable o legacy anon; nunca service_role/secret.');
}
export async function verificarServicios({url,key,fetcher=fetch}){
 validarConfiguracion(url,key);
 const runId=randomUUID(),object=`${CHIAPAS}/ensayo-solo-lectura/${runId}/no-creado.png`;
 const probes=[
  {id:'auth_configuracion_publica',path:'/auth/v1/settings',grupo:'Auth',statuses:[200],control:true},
  {id:'auth_sin_sesion',path:'/auth/v1/user',grupo:'Auth',statuses:[401,403]},
  {id:'auth_token_invalido',path:'/auth/v1/user',grupo:'Auth',token:'invalid-test-token',statuses:[401,403]},
 ];
 for(const bucket of ['comprobantes-pago','fotos-promotoras']){
  for(const invalid of [false,true])probes.push({id:`storage_${bucket}_${invalid?'token_invalido':'sin_sesion'}`,
   path:`/storage/v1/object/authenticated/${bucket}/${object}`,grupo:'Storage',
   ...(invalid?{token:'invalid-test-token'}:{}),statuses:[400,401,403,404]});
 }
 const resultados=[];
 for(const probe of probes){
  const headers={apikey:key};if(probe.token)headers.authorization='Bearer '+probe.token;
  try{
   const response=await fetcher(url+probe.path,{method:'GET',headers,redirect:'error',signal:AbortSignal.timeout(15000)});
   // Never persist response bodies, request headers, keys or object contents.
   let payload;try{payload=await response.json();}catch{payload=null;}
   const code=payload?.code??payload?.error??payload?.statusCode;
   const errorCode=typeof code==='string'||typeof code==='number'?String(code).slice(0,80):null;
   resultados.push({caso:probe.id,servicio:probe.grupo,status:response.status,codigo:errorCode,
    aprobado:probe.statuses.includes(response.status)&&(!probe.control||(payload!==null&&typeof payload==='object'&&!Array.isArray(payload))),
    alcance:probe.control?'Control positivo: configuración pública Auth accesible con la clave publicable.':probe.grupo==='Auth'?'Rechazo real de consulta de usuario sin sesión válida.':'Sonda sobre ruta ficticia no creada; rechazo/no encontrado NO prueba RLS de un archivo existente.'});
  }catch{resultados.push({caso:probe.id,servicio:probe.grupo,aprobado:false,error:'Fallo de red, redirección o timeout; no se cuenta como rechazo aprobado.'});}
 }
 return {fecha_utc:new Date().toISOString(),proyecto:'rkjlqxxmxbiciuhtpnpf',evento_ficticio:CHIAPAS,run_id:runId,
  metodo:'GET exclusivamente; sin cuentas, archivos, firmas de URL, RPC o escrituras de negocio.',
  aprobado:resultados.every(r=>r.aprobado),control_api_valido:resultados[0].aprobado,resultados,
  pendientes:['Auth con sesión válida, rol/asignación activa y revocación','Storage con archivo ficticio existente, firma autorizada y denegación por evento','Vault real: emisión, recuperación y reemisión de QR ficticios','Flujo integral de frontend contra las versiones aprobadas desplegadas'],
  limites:'No valida la integración de la versión local, todavía no publicada. No se invocaron endpoints de RADEV’S; los servicios Auth y Storage son compartidos. No acredita aislamiento entre eventos ni limpieza tras escrituras. Puede generar registros técnicos de solicitudes en el proveedor.'};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 if(process.argv[2]!=='--real-read-only'||!process.argv[3]||!process.argv[4])throw Error('Uso: node scripts/verificar-servicios-solo-lectura.mjs --real-read-only archivo-env salida-nueva.json');
 const [, , ,envPath,output]=process.argv;
 if(fs.existsSync(output))throw Error('La salida ya existe; no se sobrescribe.');
 const values={};
 for(const line of fs.readFileSync(envPath,'utf8').split(/\r?\n/)){
  const match=line.match(/^\s*(VITE_SUPABASE_URL|VITE_SUPABASE_PUBLISHABLE_KEY)\s*=\s*(.*?)\s*$/);
  if(match)values[match[1]]=match[2].replace(/^(['"])(.*)\1$/,'$2');
 }
 const result=await verificarServicios({url:values.VITE_SUPABASE_URL,key:values.VITE_SUPABASE_PUBLISHABLE_KEY});
 fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(`${result.resultados.filter(r=>r.aprobado).length}/${result.resultados.length} sondas HTTP aprobadas; integración completa pendiente. Reporte sin credenciales.`);
 if(!result.aprobado)process.exitCode=1;
}
