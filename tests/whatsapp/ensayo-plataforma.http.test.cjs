// Real HTTP on loopback. Supabase/Auth/Storage responses are synthetic; no production traffic.
const {createServer}=require('node:http');const {spawn}=require('node:child_process');
const fs=require('node:fs/promises');const path=require('node:path');const assert=require('node:assert/strict');
const net=require('node:net');
async function port(){const s=net.createServer();await new Promise((r,j)=>s.once('error',j).listen(0,'127.0.0.1',r));const p=s.address().port;await new Promise(r=>s.close(r));return p;}
(async()=>{
 const root=process.env.FIESTA_ENSAYO_EDGE_ROOT;if(!root)throw Error('Solo copia local aislada');
 let activo=true,asignado=true,rol='administrador',auth=true,uploads=0,rpcs=0,checks=0;
 const admin='a1111111-1111-4111-8111-111111111111';
 const backend=createServer(async(req,res)=>{const chunks=[];for await(const c of req)chunks.push(c);const raw=Buffer.concat(chunks).toString();const u=new URL(req.url,'http://127.0.0.1');res.setHeader('Content-Type','application/json');
  if(u.pathname==='/auth/v1/user'){res.statusCode=auth?200:401;res.end(JSON.stringify(auth?{id:admin,email:'fixture@example.test'}:{message:'invalid',code:'bad_jwt'}));return;}
  if(u.pathname==='/rest/v1/usuarios'){res.end(JSON.stringify({rol,activo}));return;}
  if(u.pathname==='/rest/v1/usuarios_eventos'){res.end(JSON.stringify(asignado?{usuario_id:admin}:null));return;}
  if(u.pathname==='/rest/v1/rpc/whatsapp_ensayo_control_interno'){rpcs++;const b=JSON.parse(raw);assert.equal(b.p_admin,admin);res.end(JSON.stringify({ok:true,es_prueba:true,estado_registro:b.p_accion==='confirmar'?'confirmado':'pendiente'}));return;}
  if(u.pathname.startsWith('/storage/v1/object/fotos-promotoras/')){uploads++;assert.ok(u.pathname.endsWith('/3dc92160-79af-4bf7-b770-263038e88900/pruebas/2bba9e9e-8751-49df-b1bb-17a82c7120d3.png'));res.end(JSON.stringify({Key:'foto-fixture',Id:admin}));return;}
  res.statusCode=404;res.end('{}');
 });
 await new Promise(r=>backend.listen(0,'127.0.0.1',r));const backendPort=backend.address().port,edgePort=await port();
 const harness=path.join(root,'harness.mjs');
 await fs.writeFile(harness,`const original=Deno.serve;Deno.serve=(handler)=>original({hostname:'127.0.0.1',port:${edgePort}},handler);await import('./supabase/functions/whatsapp-ensayo-plataforma/index.ts');`);
 const child=spawn(process.env.FIESTA_DENO_PATH||'C:/Users/ihugo/.deno/bin/deno.exe',['run','--no-config','--node-modules-dir=none','--lock=supabase/whatsapp-edge.lock','--frozen=true','--allow-env','--allow-net=127.0.0.1','--allow-read',harness],{cwd:root,env:{...process.env,SUPABASE_URL:`http://127.0.0.1:${backendPort}`,SUPABASE_SERVICE_ROLE_KEY:'fixture-only-backend',WHATSAPP_ENSAYO_PLATAFORMA_HABILITADO:'true',WHATSAPP_ENVIOS_HABILITADOS:'false',WHATSAPP_MODO:'simulacion',META_WHATSAPP_PHONE_NUMBER_ID:'1302305149644004',WHATSAPP_TEST_DESTINATARIO:process.env.FIESTA_TEST_DESTINATARIO},stdio:['ignore','pipe','pipe']});
 const logs=[];child.stdout.on('data',b=>logs.push(b.toString()));child.stderr.on('data',b=>logs.push(b.toString()));
 try{
  const url=`http://127.0.0.1:${edgePort}`;let ready=false;
  for(let i=0;i<150;i++){if(child.exitCode!==null)throw Error('Edge local terminó: '+logs.join(''));try{await fetch(url,{method:'OPTIONS'});ready=true;break;}catch{}await new Promise(r=>setTimeout(r,100));}
  assert(ready);const jwt='eyJhbGciOiJIUzI1NiJ9.'+Buffer.from(JSON.stringify({sub:admin,exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.fixture';
  const post=(body,token=jwt,origin='http://localhost:5173')=>fetch(url,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),Origin:origin},body:JSON.stringify(body)});
  const check=(a,b)=>{assert.deepEqual(a,b);checks++;};
  check((await fetch(url,{method:'OPTIONS'})).status,204);
  check((await post({accion:'estado'},null)).status,401);check(uploads,0);
  auth=false;check((await post({accion:'estado'})).status,401);auth=true;
  activo=false;check((await post({accion:'crear',confirmar:true})).status,403);activo=true;
  asignado=false;check((await post({accion:'crear',confirmar:true})).status,403);asignado=true;
  rol='recepcion';check((await post({accion:'crear',confirmar:true})).status,403);rol='administrador';
  check((await post({accion:'crear',confirmar:true},jwt,'https://ajeno.example')).status,403);
  check((await post({accion:'crear'})).status,400);
  check((await post({accion:'crear',confirmar:true,telefono:'otro'})).status,400);
  check(uploads,0);check(rpcs,0);
  const created=await post({accion:'crear',confirmar:true});check(created.status,200);check(created.headers.get('access-control-allow-origin'),'http://localhost:5173');check((await created.json()).es_prueba,true);check(uploads,1);
  check((await post({accion:'confirmar',confirmar:true})).status,200);
  const state=await post({accion:'estado'});check(state.status,200);check((await state.text()).includes('token_qr'),false);
  check((await post({accion:'procesar',confirmar:true})).status,503); // Missing Meta credentials never reserves/sends.
  console.log(`${checks} comprobaciones HTTP locales de ensayo correctas; Auth/Storage/RPC simulados, sin red externa.`);
 }finally{child.kill();await new Promise(r=>backend.close(r));}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
