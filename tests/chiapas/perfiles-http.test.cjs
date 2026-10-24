// Real Edge handler, simulated Auth/DB interfaces. SQL transaction tested separately.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path'),assert=require('node:assert/strict'),ts=require('typescript');
const USER='aa111111-1111-4111-8111-111111111111',NEW='aa222222-2222-4222-8222-222222222222';
const EVENT='3dc92160-79af-4bf7-b770-263038e88900';
function entorno(fail=false){
 let handler;const rpc=[],deleted=[];
 const db={auth:{getUser:async()=>({data:{user:{id:USER}},error:null}),admin:{
  createUser:async()=>({data:{user:{id:NEW}},error:null}),deleteUser:async id=>{deleted.push(id);return {error:null};}
 }},from:table=>{
  const f={};const q={select(){return q},eq(k,v){f[k]=v;return q},neq(){return q},limit(){return q}};
  const result=single=>({error:null,data:table==='usuarios'
   ?(f.nombre_usuario?null:{id:USER,rol:'administrador',activo:true})
   :(single?{usuario_id:USER}:[{usuario_id:USER}])});
  q.maybeSingle=q.single=async()=>result(true);q.then=(a,b)=>Promise.resolve(result(false)).then(a,b);return q;
 },rpc:async(name,args)=>{rpc.push({name,args});return {data:null,error:fail?{code:'23505',message:'duplicate fixture'}:null}}};
 function load(file){const exports={};const js=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText;
  vm.runInNewContext(js,{exports,require:name=>name.includes('supabase-js')?{createClient:()=>db}:load(path.resolve(path.dirname(file),name)),Deno:{serve:h=>handler=h,env:{get:()=> 'fixture-only'}},Request,Response,Headers,TextDecoder,TextEncoder,Uint8Array,crypto,console},{filename:file});return exports;}
 load(path.resolve('supabase/functions/gestionar-usuarios/index.ts'));
 return {rpc,deleted,call:()=>handler(new Request('http://localhost',{method:'POST',headers:{Authorization:'Bearer fixture','Content-Type':'application/json'},body:JSON.stringify({evento_id:EVENT,accion:'crear',nombre:'PRUEBA LOCAL',nombre_usuario:'prueba.local',rol:'acceso',password:'ClaveLocal12345',admin_id:'attacker'})}))};
}
(async()=>{
 const ok=entorno();assert.equal((await ok.call()).status,200);assert.equal(ok.rpc.length,1);assert.equal(ok.rpc[0].name,'crear_perfil_evento_interno');
 assert.equal(ok.rpc[0].args.p_admin_id,USER);assert.equal(ok.rpc[0].args.p_evento_id,EVENT);assert.equal(ok.rpc[0].args.p_usuario_id,NEW);assert.deepEqual(ok.deleted,[]);
 const fail=entorno(true);assert.equal((await fail.call()).status,400);assert.deepEqual(fail.deleted,[NEW]);assert.equal(fail.rpc.length,1);
 console.log('10 comprobaciones de creación atómica y limpieza Auth aprobadas; backend simulado.');
})().catch(e=>{console.error(e.message);process.exitCode=1});
