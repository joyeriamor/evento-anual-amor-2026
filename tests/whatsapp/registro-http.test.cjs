// Real handlers + actual loopback HTTP. Supabase, Storage and CAPTCHA are simulated.
const fs=require('node:fs'),vm=require('node:vm'),http=require('node:http'),assert=require('node:assert/strict');
const ts=require('../../node_modules/typescript/lib/typescript.js');
const R='43e67bda-d19d-4c0e-a639-e85f2d62f294',C='3dc92160-79af-4bf7-b770-263038e88900';
let checks=0;
(async()=>{
 for(const[endpoint,event]of[['registrar-participante-v2',R],['registrar-participante-chiapas',C]]){
  const calls=[],uploads=[];let handler;
  const db={from:table=>{assert.equal(table,'asesores');return{select(){return this},eq(){return this},maybeSingle:async()=>({data:{nombre:'LUIS',activo:true},error:null})}},
   rpc:async(name,args)=>{calls.push({name,args});return{data:name==='comprobar_limite_registro'?true:{ok:true,folio:'FOLIO_FICTICIO',registro_id:'aa111111-1111-4111-8111-111111111111'},error:null}},
   storage:{from:bucket=>({upload:async p=>{uploads.push({bucket,path:p});return{error:null}},remove:async()=>({error:null})})}};
  const env={SUPABASE_URL:'http://127.0.0.1:54321',SUPABASE_SERVICE_ROLE_KEY:'FICTICIO_NO_REAL',TURNSTILE_SECRET_KEY:'FICTICIO',REGISTRO_RATE_LIMIT_SECRET:'FICTICIO',TURNSTILE_ALLOWED_HOSTNAMES:'localhost',REGISTROS_HABILITADOS:'true',REGISTROS_CHIAPAS_HABILITADOS:'true',FOTO_BUCKET:'fotos-ficticias',COMPROBANTE_BUCKET:'comprobantes-ficticios',MAX_REGISTROS_EVENTO:String(event===C?500:1500)};
  const code=ts.transpileModule(fs.readFileSync(`supabase/functions/${endpoint}/index.ts`,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
  vm.runInNewContext(code,{exports:{},require:name=>{assert(name.includes('supabase-js'));return{createClient:()=>db}},Deno:{serve:f=>handler=f,env:{get:n=>env[n]}},
   Request,Response,Headers,File,FormData,TextDecoder,TextEncoder,Uint8Array,URLSearchParams,AbortSignal,crypto,console,
   fetch:async url=>{assert.equal(url,'https://challenges.cloudflare.com/turnstile/v0/siteverify');return Response.json({success:true,hostname:'localhost'})}});
  const server=http.createServer(async(req,res)=>{try{
   const parts=[];for await(const p of req)parts.push(p);
   const answer=await handler(new Request('http://localhost/registro',{method:'POST',headers:req.headers,body:Buffer.concat(parts)}));
   res.writeHead(answer.status,Object.fromEntries(answer.headers));res.end(await answer.text());
  }catch{res.writeHead(500);res.end('Fallo local');}});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{for(const consentimiento of [undefined,'false','true'])for(const tipo of ['vendedora','promotora']){
   calls.length=0;uploads.length=0;const form=new FormData();
   for(const[k,v]of Object.entries({nombres:'FICTICIA',apellidos:'ENSAYO',estado:'Chiapas',whatsapp:'9610000001',asesor_id:'aa111111-1111-4111-8111-111111111111',tipo_participante:tipo,grupo_ruta:'RUTA FICTICIA',privacidad_aceptada:'true',turnstile_token:'TOKEN_FICTICIO_CAPTCHA_NO_REAL_12345',evento_id:event===C?R:C}))form.set(k,v);
   if(consentimiento!==undefined)form.set('autoriza_whatsapp',consentimiento);
   const png=new Uint8Array([137,80,78,71,13,10,26,10,0]);form.set('foto',new File([png],'ficticia.png',{type:'image/png'}));
   if(tipo==='vendedora'){form.set('comprobante',new File([png],'pago-ficticio.png',{type:'image/png'}));form.set('cuenta_destino','bbva-laura');}
   const res=await fetch(`http://127.0.0.1:${server.address().port}/registro`,{method:'POST',headers:{'cf-connecting-ip':'127.0.0.1'},body:form});
   assert.equal(res.status,200,await res.clone().text());checks++;
   const rpc=calls.find(c=>c.name==='crear_registro_publico_v4');assert(rpc);assert.equal(rpc.args.p_acepta_whatsapp,consentimiento==='true');checks++;
   assert.equal(rpc.args.p_evento_id,event);assert(uploads.every(u=>u.path.startsWith(event+'/')));checks++;
   assert.equal(uploads.length,tipo==='vendedora'?2:1);checks++;
  }}finally{await new Promise(r=>server.close(r));}
 }
 console.log(`${checks} comprobaciones de registro y consentimiento: HTTP localhost real, Supabase/Storage/CAPTCHA simulados.`);
})().catch(e=>{console.error(e);process.exitCode=1});
