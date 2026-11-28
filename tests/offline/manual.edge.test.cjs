const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require('typescript');
const E='43e67bda-d19d-4c0e-a639-e85f2d62f294';
const C='3dc92160-79af-4bf7-b770-263038e88900';
const D='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
const P='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
const OP='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3';
const REG='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',INV='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
const source=fs.readFileSync('supabase/functions/acceso-offline-manual/index.ts','utf8');
const compiled=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
assert.equal(compiled.diagnostics.filter(d=>d.category===1).length,0);
function setup(mode={}) {
 let handler, calls=[],signatures=[];
 const auth={rpc:async(name,args)=>{
  calls.push({name,args});
  if(mode.rpcError)return{data:null,error:{message:'dato interno secreto'}};
  if(name==='offline_descargar')return{error:null,data:{ok:true,evento_id:E,
   participantes:[{foto_path:E+'/solo-evento.png'}]}};
  return {error:null,data:{ok:true,estado:'ingreso_registrado'}};
 }};
 const service={storage:{from(bucket){
  assert.equal(bucket,'fotos-promotoras');
  return {createSignedUrls:async(paths,ttl)=>{
   signatures.push(paths);assert.equal(ttl,3600);
   if(mode.photoError)return{error:{},data:null};
   return {error:null,data:paths.map(path=>({path,signedUrl:'https://ficticio.test/'+path}))};
  }};
 }}};
 vm.runInNewContext(compiled.outputText,{
  exports:{},Map,Set,Response,Date,JSON,console,
  Deno:{env:{get:k=>({SUPABASE_URL:'https://ficticio.test',SUPABASE_ANON_KEY:'publica',SUPABASE_SERVICE_ROLE_KEY:'solo-servidor'}[k])}},
  require(name){
   if(name.includes('_shared'))return{serveEvento:(opts,fn)=>{assert.deepEqual([...opts.roles],['administrador','acceso']);handler=fn;}};
   if(name.includes('supabase-js'))return{createClient:(_url,key,opts)=>{
    if(key==='solo-servidor')return service;
    assert.equal(opts.global.headers.Authorization,'Bearer sesion-ficticia');return auth;
   }};
   throw Error(name);
  }
 });
 return{handler,calls,signatures};
}
(async()=>{
 let count=0;
 const entry={operacion_id:OP,registro_id:REG,invitacion_id:INV,identidad_confirmada:true,ingresado_at:new Date().toISOString()};
 const valid={accion:'sincronizar',evento_id:E,dispositivo_id:D,paquete_id:P,accesos:[entry]};
 const cases=[
  [{...valid,dispositivo_id:'otro'},400],
  [{...valid,accion:'borrar'},400],
  [{...valid,paquete_id:null},400],
  [{...valid,accesos:[]},400],
  [{...valid,accesos:Array(26).fill(entry)},400],
  [{...valid,accesos:[entry,entry]},400],
  [{...valid,accesos:[{...entry,registro_id:'x'}]},400],
  [{...valid,accesos:[{...entry,invitacion_id:null}]},400],
  [{...valid,accesos:[{...entry,identidad_confirmada:false}]},400],
  [{...valid,accesos:[{...entry,identidad_confirmada:'true'}]},400],
  [{...valid,accesos:[{...entry,operacion_id:OP.toUpperCase()},entry]},400],
  [{...valid,accesos:[{...entry,ingresado_at:'ayer'}]},400],
  [{...valid,accesos:[null]},400],
 ];
 for(const [body,status] of cases){
  const test=setup();
  const r=await test.handler(new Request('https://local.test',{method:'POST',
   headers:{'authorization':'Bearer sesion-ficticia','x-evento-autorizado':E,'content-type':'application/json'},
   body:JSON.stringify(body)}));
  assert.equal(r.status,status);assert.equal(test.calls.length,0);count++;
 }
 for(const evento of [E,C]){
  const t=setup();
  const r=await t.handler(new Request('https://local.test',{method:'POST',headers:{
   authorization:'Bearer sesion-ficticia','x-evento-autorizado':evento,'content-type':'application/json'
  },body:JSON.stringify({...valid,evento_id:evento,usuario_id:'no-confiable'})}));
  assert.equal(r.status,200);const response=await r.json();
  assert.equal(response.resultados[0].operacion_id,OP);
  assert.equal(t.calls[0].args.p_evento_id,evento);
  assert.equal('p_usuario_id' in t.calls[0].args,false);
  assert.equal(t.calls[0].name,'offline_sincronizar_manual');assert.equal(t.calls[0].args.p_registro_id,REG);
  assert.equal(t.calls[0].args.p_invitacion_id,INV);assert.equal(t.calls[0].args.p_identidad_confirmada,true);count++;
 }
 for(const [mode,accion,status] of [[{rpcError:true},'sincronizar',409]]){
  const t=setup(mode),r=await t.handler(new Request('https://local.test',{method:'POST',headers:{
   authorization:'Bearer sesion-ficticia','x-evento-autorizado':E,'content-type':'application/json'
  },body:JSON.stringify({...valid,accion})}));
  assert.equal(r.status,status);assert.equal((await r.text()).includes('dato interno secreto'),false);count++;
 }
 console.log(count+' comprobaciones Edge manual aprobadas. Auth y RPC simulados; sin producción.');
})().catch(e=>{console.error(e);process.exitCode=1;});
