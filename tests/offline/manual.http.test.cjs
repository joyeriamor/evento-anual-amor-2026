// Real loopback HTTP and actual guard/handler; Supabase Auth/RPC are simulated.
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const ts=require('typescript');
const E='43e67bda-d19d-4c0e-a639-e85f2d62f294',C='3dc92160-79af-4bf7-b770-263038e88900';
const ID='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',USER='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
const valido={accion:'sincronizar',evento_id:E,dispositivo_id:ID,paquete_id:ID,accesos:[{
 operacion_id:ID,registro_id:ID,invitacion_id:ID,ingresado_at:new Date().toISOString(),identidad_confirmada:true}]};
function entorno(estado={}){
 let handler;const llamadas=[];
 const db={auth:{getUser:async token=>({data:{user:token==='valid'?{id:USER}:null},error:null})},
  from(tabla){const b={select:()=>b,eq:()=>b,maybeSingle:async()=>({error:null,data:tabla==='usuarios'?
   {rol:estado.rol||'administrador',activo:estado.activo!==false}:estado.asignacion===false?null:{usuario_id:USER}})};return b;},
  rpc:async(nombre,args)=>{llamadas.push({nombre,args});return{data:{ok:true,estado:'ingreso_registrado'},error:null};}};
 function cargar(file){
  const compilado=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
  const exports={};vm.runInNewContext(compilado.outputText,{exports,
   require:n=>n.includes('supabase-js')?{createClient:(_url,key,opciones)=>{
    if(key==='publica')assert.equal(opciones.global.headers.Authorization,'Bearer valid');return db;
   }}:cargar(path.resolve(path.dirname(file),n)),
   Deno:{serve:f=>{handler=f;},env:{get:n=>({SUPABASE_URL:'https://ficticio.test',SUPABASE_SERVICE_ROLE_KEY:'solo-servidor',SUPABASE_ANON_KEY:'publica'}[n])}},
   Request,Response,Headers,TextDecoder,Uint8Array,console,Date,Map,Set});return exports;
 }
 cargar(path.resolve('supabase/functions/acceso-offline-manual/index.ts'));
 return{handler,llamadas};
}
(async()=>{
 let contexto=entorno(),checks=0;
 const servidor=http.createServer(async(req,res)=>{
  try{const bytes=[];for await(const c of req)bytes.push(c);
   const response=await contexto.handler(new Request('http://localhost/ingreso',{method:req.method,headers:req.headers,
    body:req.method==='POST'?Buffer.concat(bytes):undefined}));
   res.writeHead(response.status,Object.fromEntries(response.headers));res.end(await response.text());
  }catch{res.writeHead(500);res.end();}
 });
 await new Promise(resolve=>servidor.listen(0,'127.0.0.1',resolve));
 try{
  const url=`http://127.0.0.1:${servidor.address().port}`;
  for(const [estado,token,cuerpo,status] of [
   [{},null,valido,401],[{},'invalid',valido,401],[{activo:false},'valid',valido,403],
   [{rol:'asesor'},'valid',valido,403],[{asignacion:false},'valid',valido,403],
   [{},'valid',{...valido,evento_id:ID},403],[{},'valid',[],400],
   [{},'valid',{...valido,relleno:'x'.repeat(17000)},413],
   [{},'valid',{...valido,accesos:[{...valido.accesos[0],identidad_confirmada:false}]},400]]){
    contexto=entorno(estado);const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(cuerpo)});
    assert.equal(r.status,status);assert.equal(contexto.llamadas.length,0);checks++;
  }
  for(const [evento,rol] of [[E,'administrador'],[C,'administrador'],[C,'acceso']]){
   contexto=entorno({rol});const r=await fetch(url,{method:'POST',headers:{Authorization:'Bearer valid','content-type':'application/json','x-evento-autorizado':'forged'},
    body:JSON.stringify({...valido,evento_id:evento,admin_id:'cliente-no-confiable'})});
   assert.equal(r.status,200);assert.equal((await r.json()).resultados[0].ok,true);
   assert.equal(contexto.llamadas[0].args.p_evento_id,evento);assert.equal(contexto.llamadas[0].nombre,'offline_sincronizar_manual');
   assert.equal('p_admin_id' in contexto.llamadas[0].args,false);assert.equal(r.headers.get('cache-control'),'no-store');checks++;
  }
  for(const [method,status] of [['GET',405],['OPTIONS',204]]){
   contexto=entorno();assert.equal((await fetch(url,{method})).status,status);assert.equal(contexto.llamadas.length,0);checks++;
  }
  console.log(checks+' comprobaciones HTTP manual aprobadas; transporte y guard reales en localhost, Auth/RPC simulados.');
 }finally{await new Promise(resolve=>servidor.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
