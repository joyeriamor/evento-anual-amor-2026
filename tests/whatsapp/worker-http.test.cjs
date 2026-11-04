// The actual backend handler over localhost HTTP; database, image and Meta transports simulated.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),http=require('node:http'),assert=require('node:assert/strict');
const ts=require('../../node_modules/typescript/lib/typescript.js');
const secreto='FICTICIO_WORKER_SIN_VALIDEZ_1234567890';
const contexto={elegible:true,invitacion_id:'inv',registro_id:'reg',evento_id:'3dc92160-79af-4bf7-b770-263038e88900',token_qr:'TOKEN_FICTICIO_QR_1234567890',telefono:'529611234567',folio:'FICTICIO',participante:'FICTICIA',evento:'Fiesta Anual AMOR 2026',fecha:'19 de diciembre de 2026',recepcion:'Por confirmar',lugar:'Salón BIANCO'};
let checks=0;
async function caso(envExtra,headers,esperado,estado,metaEsperado=[]){
 let handler;const meta=[],rpc=[];
 const env={SUPABASE_URL:'http://127.0.0.1:54321',SUPABASE_SERVICE_ROLE_KEY:'FICTICIO',WHATSAPP_WORKER_SECRET:secreto,...envExtra};
 const db={rpc:async(name,args)=>{rpc.push({name,args});let data=true;
  if(name==='whatsapp_reservar_interno')data={id:'job',invitacion_id:'inv',reserva_id:'reserva'};
  if(name==='whatsapp_contexto_interno'||name==='whatsapp_autorizar_salida_interno')data=contexto;
  if(name==='whatsapp_reservar_limpieza_interno')data={id:'job',reserva_id:'reserva',media_id:'123'};
  return{data,error:null};}};
 function load(file){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText,
  {exports,require:name=>{
   if(name.includes('supabase-js'))return{createClient:()=>db};
   if(name.includes('whatsapp-imagen.ts'))return{generarImagen:async()=>new Uint8Array([137,80,78,71])};
   if(name.includes('whatsapp-meta.ts'))return{transporteMeta:()=>({cargar:async()=>{meta.push('media');return'123'},enviar:async()=>{meta.push('mensaje');return{id:'wamid.ficticio'}},eliminar:async()=>{meta.push('eliminar')}})};
   return load(path.resolve(path.dirname(file),name));
  },Deno:{serve:f=>handler=f,env:{get:n=>env[n]}},Request,Response,Headers,TextEncoder,Uint8Array,crypto,console});return exports;}
 load(path.resolve('supabase/functions/whatsapp-procesar-cola/index.ts'));
 const server=http.createServer(async(req,res)=>{try{const response=await handler(new Request('http://localhost/worker',{method:'POST',headers:req.headers}));res.writeHead(response.status,Object.fromEntries(response.headers));res.end(await response.text());}catch{res.writeHead(500);res.end('Fallo local')}});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try{const r=await fetch(`http://127.0.0.1:${server.address().port}`,{method:'POST',headers});assert.equal(r.status,esperado);checks++;
  const body=await r.json();if(estado){assert.equal(body.estado,estado);checks++}assert.deepEqual(meta,metaEsperado);checks++;
  if(esperado>=400){assert.equal(rpc.length,0);checks++}
 }finally{await new Promise(r=>server.close(r))}
}
(async()=>{
 await caso({}, {},401);
 await caso({}, {Authorization:'Bearer JWT_ADMIN_FICTICIO'},401);
 await caso({}, {'x-whatsapp-worker-secret':'INCORRECTO'},401);
 await caso({}, {'x-whatsapp-worker-secret':secreto,Origin:'https://externo.example'},403);
 await caso({}, {'x-whatsapp-worker-secret':secreto},200,'simulado');
 await caso({WHATSAPP_MODO:'real'},{'x-whatsapp-worker-secret':secreto},200,'deshabilitado');
 await caso({WHATSAPP_LIMPIEZA_HABILITADA:'true',WHATSAPP_PRODUCCION_AUTORIZADA:'true'},{'x-whatsapp-worker-secret':secreto,'x-whatsapp-tarea':'limpiar'},200,'limpieza_deshabilitada');
 await caso({WHATSAPP_MODO:'real',WHATSAPP_LIMPIEZA_HABILITADA:'true',WHATSAPP_PRODUCCION_AUTORIZADA:'true'},{'x-whatsapp-worker-secret':secreto,'x-whatsapp-tarea':'limpiar'},200,'medio_eliminado',['eliminar']);
 console.log(`${checks} comprobaciones del worker: HTTP localhost real, backend/Meta simulados.`);
})().catch(e=>{console.error(e);process.exitCode=1});
