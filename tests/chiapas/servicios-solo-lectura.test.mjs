// Offline tests of probe safety and reporting. This file never calls the network.
import assert from 'node:assert/strict';
import { validarConfiguracion,verificarServicios,PROJECT_URL } from '../../scripts/verificar-servicios-solo-lectura.mjs';
let checks=0;
const key='sb_publishable_test_only';
for(const [url,bad] of [[PROJECT_URL,'sb_secret_private'],['https://example.com',key],[PROJECT_URL,'not-a-key']]){
 assert.throws(()=>validarConfiguracion(url,bad));checks++;
}
const service=Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url');
assert.throws(()=>validarConfiguracion(PROJECT_URL,`header.${service}.signature`));checks++;
let requests=[];
const result=await verificarServicios({url:PROJECT_URL,key,fetcher:async(url,opts)=>{
 requests.push(url);assert.equal(opts.method,'GET');assert.equal(opts.redirect,'error');
 assert.ok(!opts.body);assert.ok(!url.includes('43e67bda'));assert.ok(!url.includes('/functions/'));assert.ok(!url.includes('/rest/'));
 if(url.includes('/storage/'))assert.match(url,/3dc92160-79af-4bf7-b770-263038e88900\/ensayo-solo-lectura\/[0-9a-f-]+\/no-creado.png$/);
 return new Response(JSON.stringify({code:'bad_jwt',message:key}),{status:url.endsWith('/settings')?200:url.includes('/auth/')?401:400});
}});
assert.equal(requests.length,7);assert.equal(result.aprobado,true);assert.ok(!JSON.stringify(result).includes(key));checks++;
for(const status of [200,401,429,500]){
 const failed=await verificarServicios({url:PROJECT_URL,key,fetcher:async()=>new Response('{}',{status})});
 assert.equal(failed.aprobado,false);assert.ok(failed.resultados.some(r=>!r.aprobado));checks++;
}
const network=await verificarServicios({url:PROJECT_URL,key,fetcher:async()=>{throw Error('secret '+key);}});
assert.equal(network.aprobado,false);assert.ok(!JSON.stringify(network).includes(key));checks++;
let called=false;
await assert.rejects(verificarServicios({url:'https://example.com',key,fetcher:async()=>{called=true;}}));
assert.equal(called,false);checks++;
console.log(`${checks} comprobaciones locales del verificador: solo GET, proyecto fijo, sin datos/secretos, fallos reales no cuentan como aprobados. Sin tráfico remoto.`);
