// Executes real TypeScript handlers with simulated Supabase. No production traffic.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const http = require('node:http');
const ts = require('../../node_modules/typescript/lib/typescript.js');
const RADEVS = '43e67bda-d19d-4c0e-a639-e85f2d62f294';
const CHIAPAS = '3dc92160-79af-4bf7-b770-263038e88900';
const USER = 'aa111111-1111-4111-8111-111111111111';
const ID = 'bb111111-1111-4111-8111-111111111111';
const endpoints = ['validar-pago','administrar-invitacion','bandejas-admin','bandeja-personal',
  'validar-pago-chiapas','administrar-invitacion-chiapas','bandejas-admin-chiapas','bandeja-personal-chiapas',
  'listar-participantes','detalle-participante','consultar-acceso','consultar-acceso-evento',
  'resumen-accesos','gestionar-usuarios','registrar-prueba-admin','resumen-cupo-evento','verificar-personal','verificar-admin','probar-limite-registro','registrar-prueba-admin-chiapas'];
function entorno(nombre, estado = {}) {
  let handler;
  const queries = [], rpc = [], signed = [], uploads = [], removals = [];
  function from(tabla) {
    const filters = [];
    const q = { tabla, filters }; queries.push(q);
    const builder = {};
    for (const metodo of ['select','eq','neq','in','order','limit','range','or','ilike']) {
      builder[metodo] = (...args) => { filters.push([metodo,...args]); return builder; };
    }
    const result = () => {
      if (tabla === 'usuarios') return { data: { id: USER, rol: estado.rol || 'administrador', activo: estado.activo !== false }, error: null };
      if (tabla === 'asesores') return { data: {nombre:estado.empleado?'EMPLEADO':'ASESOR FICTICIO',activo:true}, error:null };
      if (tabla === 'usuarios_eventos') return { data: estado.asignacion === false ? null : { usuario_id: USER }, error: estado.errorAsignacion ? { message: 'fail' } : null };
      if (tabla === 'pagos' || tabla === 'registros') return { data: estado.objetivo ? { id: ID, evento_id: estado.evento || RADEVS } : null, error: null, count: 0 };
      return { data: [], error: null, count: 0 };
    };
    builder.single = builder.maybeSingle = async () => result();
    builder.then = (resolve,reject) => Promise.resolve(result()).then(resolve,reject);
    return builder;
  }
  const db = { from, auth: { getUser: async token => ({ data: { user: estado.invalido || token === 'invalid' ? null : { id: USER } }, error: null }) },
    rpc: async (name,args) => { rpc.push([name,args]); return { data: name === 'comprobar_limite_registro' ? estado.limitePermitido !== false : estado.rpcFalla ? {ok:false,codigo:'DUPLICADO'} : { ok: true, total: 0, registros: [], capacidad: 500 }, error: null }; },
    storage: { from: bucket => ({ upload:async p=>{uploads.push([bucket,p]);return {error:null};},remove:async paths=>{removals.push([bucket,paths]);return {error:null};}, createSignedUrl: async p => { signed.push([bucket,p]); return { data: { signedUrl: 'signed' } }; } }) } };
  function load(file) {
    const output = ts.transpileModule(fs.readFileSync(file,'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } });
    const exports = {};
    vm.runInNewContext(output.outputText, { exports, require: name => name.includes('supabase-js') ? { createClient: () => db } : load(path.resolve(path.dirname(file),name)),
      Deno: { serve: f => { handler = f; }, env: { get: name => estado.sinMax && name.startsWith('MAX_') ? undefined : 'local-test-only' } },
      Request, Response, Headers, TextDecoder, TextEncoder, Uint8Array, console, crypto, File, FormData,
    }, { filename: file });
    return exports;
  }
  load(path.resolve('supabase/functions',nombre,'index.ts'));
  return { call: (body = {}, headers = {}, method = 'POST') => handler(new Request('http://local.test', {
    method, headers: { ...(body instanceof FormData?{}:{'content-type':'application/json'}), ...headers }, ...(method === 'POST' ? { body: body instanceof FormData ? body : JSON.stringify(body) } : {}),
  })), queries,rpc,signed,uploads,removals };
}
let count = 0;
async function check(name, state, body, headers, expected) {
  const e = entorno(name,state); const res = await e.call(body,headers);
  assert.equal(res.status,expected,`${name}: ${await res.clone().text()}`);
  if (expected >= 400) { assert.equal(e.rpc.length,0); assert.equal(e.signed.length,0); }
  count++; return e;
}
(async () => {
  for (const name of endpoints) {
    await check(name,{}, {},{},401);
    await check(name,{invalido:true},{},{Authorization:'Bearer invalid'},401);
    await check(name,{activo:false},{},{Authorization:'Bearer valid'},403);
    await check(name,{rol:'asesor'},{},{Authorization:'Bearer valid'},403);
    if (!name.startsWith('registrar-prueba-admin')) {
      await check(name,{},[],{Authorization:'Bearer valid'},400);
      await check(name,{}, {relleno:'x'.repeat(17000)},{Authorization:'Bearer valid'},413);
    }
    await check(name,{asignacion:false},{},{Authorization:'Bearer valid'},403);
    await check(name,{errorAsignacion:true},{},{Authorization:'Bearer valid'},503);
    await check(name,{}, {evento_id:'00000000-0000-0000-0000-000000000000'},{Authorization:'Bearer valid'}, name.startsWith('registrar-prueba-admin') ? 503 : 403);
    const e=entorno(name); assert.equal((await e.call({}, {},'OPTIONS')).status,204); assert.equal(e.queries.length,0);count++;
    assert.equal((await e.call({}, {},'GET')).status,405);count++;
  }
  for (const name of ['validar-pago','validar-pago-chiapas','administrar-invitacion','administrar-invitacion-chiapas']) {
    const event = name.endsWith('chiapas') ? CHIAPAS : RADEVS;
    const e=await check(name,{}, { pago_id:ID,registro_id:ID,accion:name.startsWith('validar')?'aprobar':'cortesia' },{Authorization:'Bearer valid'},404);
    const target=e.queries.find(q=>q.tabla===(name.startsWith('validar')?'pagos':'registros'));
    assert.ok(target.filters.some(f=>f[0]==='eq' && f[1]===(name.startsWith('validar')?'registros.evento_id':'evento_id') && f[2]===event));count++;
  }
  for (const event of [RADEVS,CHIAPAS]) {
    const e=entorno('verificar-personal');
    const res=await e.call({evento_id:event,admin_id:'attacker'},{Authorization:'Bearer valid','x-evento-autorizado':'forged'});
    assert.equal(res.status,200); assert.equal((await res.json()).evento_id,event);
    assert.ok(e.queries.find(q=>q.tabla==='usuarios_eventos').filters.some(f=>f[1]==='usuario_id'&&f[2]===USER));count++;
  }
  for (const event of [RADEVS,CHIAPAS]) {
    const e=entorno('verificar-admin');
    const response=await e.call({evento_id:event,admin_id:ID},{Authorization:'Bearer valid'});
    assert.equal(response.status,200);const payload=await response.json();
    assert.equal(payload.autorizado,true);assert.equal(payload.usuario.id,USER);
    assert.ok(e.queries.find(q=>q.tabla==='usuarios_eventos').filters.some(f=>f[1]==='evento_id'&&f[2]===event));count++;
  }
  await check('probar-limite-registro',{}, {evento_id:CHIAPAS},{Authorization:'Bearer valid'},403);
  for(const allowed of [true,false]) {
    const e=entorno('probar-limite-registro',{limitePermitido:allowed});
    const response=await e.call({}, {Authorization:'Bearer valid','x-forwarded-for':'127.0.0.1'});
    assert.equal(response.status,allowed?200:429);
    assert.equal(response.headers.get('cache-control'),'no-store');
    assert.equal(e.rpc.length,1);assert.equal(e.rpc[0][0],'comprobar_limite_registro');
    const key=await crypto.subtle.importKey('raw',new TextEncoder().encode('local-test-only'),{name:'HMAC',hash:'SHA-256'},false,['sign']);
    const hash=Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(`prueba:registro:${RADEVS}:ip:127.0.0.1`)))).map(b=>b.toString(16).padStart(2,'0')).join('');
    assert.equal(e.rpc[0][1].p_clave,hash);count++;
  }
  // Real multipart stream, synthetic files and mock backend: Chiapas-only upload/RPC.
  for(const state of [{sinMax:true},{sinMax:true,rpcFalla:true},{sinMax:true,empleado:true}]) {
    const e=entorno('registrar-prueba-admin-chiapas',state),fd=new FormData();
    for(const [key,value] of Object.entries({nombres:'PRUEBA CHIAPAS',apellidos:'FICTICIA',estado:'Chiapas',whatsapp:'5500004173',asesor_id:ID,tipo_participante:'vendedora',grupo_ruta:'ENSAYO',cuenta_destino:'bbva-laura',confirmar_prueba:'true',privacidad_aceptada:'true'}))fd.set(key,value);
    const png=new Uint8Array([137,80,78,71,13,10,26,10,0]);
    fd.set('foto',new File([png],'prueba.png',{type:'image/png'}));
    fd.set('comprobante',new File([png],'prueba-pago.png',{type:'image/png'}));
    const response=await e.call(fd,{Authorization:'Bearer valid'});
    assert.equal(response.status,state.empleado?400:state.rpcFalla?409:200,await response.clone().text());
    if(state.empleado){assert.equal(e.uploads.length,0);assert.equal(e.rpc.length,0);}
    else {
      assert.equal(e.uploads.length,2);assert.ok(e.uploads.every(x=>x[1].startsWith(CHIAPAS+'/pruebas/')));
      assert.equal(e.rpc[0][0],'crear_registro_prueba_admin_v2');assert.equal(e.rpc[0][1].p_evento_id,CHIAPAS);
      assert.equal(e.removals.length,state.rpcFalla?2:0);
    }count++;
  }
  // Actual loopback HTTP transport; backend remains simulated, explicitly.
  const e=entorno('verificar-personal');
  const server=http.createServer(async (req,res)=>{
    const chunks=[];for await(const c of req)chunks.push(c);
    const response=await e.call(JSON.parse(Buffer.concat(chunks).toString()||'{}'),req.headers);
    res.writeHead(response.status,Object.fromEntries(response.headers));res.end(await response.text());
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  try {
    const url=`http://127.0.0.1:${server.address().port}`;
    assert.equal((await fetch(url,{method:'POST',body:'{}'})).status,401);count++;
    const res=await fetch(url,{method:'POST',headers:{Authorization:'Bearer valid'},body:JSON.stringify({evento_id:CHIAPAS})});
    assert.equal(res.status,200);assert.equal((await res.json()).evento_id,CHIAPAS);count++;
  } finally { await new Promise(resolve=>server.close(resolve)); }
  console.log(`${count} comprobaciones aprobadas. Supabase simulado; transporte HTTP local real.`);
})().catch(e=>{console.error(e);process.exitCode=1;});
