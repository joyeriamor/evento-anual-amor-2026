// Compare read-only connector exports with local sources. Never calls Supabase.
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
const [catalogPath,edgePath,output]=process.argv.slice(2);
if(!catalogPath||!edgePath||!output)throw Error('Uso: node scripts/comparar-publicado-local.mjs catalog.json edge.json output.json');
const live=JSON.parse(fs.readFileSync(catalogPath,'utf8'));
const edges=JSON.parse(fs.readFileSync(edgePath,'utf8'));
const expected=JSON.parse(fs.readFileSync('tests/fixtures/catalogo_esquema_20261024.json','utf8'));
const rpc=JSON.parse(fs.readFileSync('tests/fixtures/catalogo_rpc_20261024.json','utf8'));
const stable=x=>Array.isArray(x)?x.map(stable):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).sort().map(k=>[k,stable(x[k])])):x;
const rows=x=>x.map(v=>JSON.stringify(stable(v))).sort();
const sha=s=>createHash('sha256').update(s).digest('hex');
const delta=(a,b)=>({faltan:a.filter(x=>!b.includes(x)),adicionales:b.filter(x=>!a.includes(x))});
const structure={};
for(const [key,values] of Object.entries(expected)){
 let actual=live[key];
 if(key==='columns')actual=actual.map(x=>Object.fromEntries(Object.entries(x).filter(([k,v])=>k!=='identidad'||v)));
 structure[key]=delta(rows(values),rows(actual));
}
const select=f=>Object.fromEntries(['firma','nombre','security_definer','acl','hash'].map(k=>[k,f[k]]));
structure.functions=delta(rows(rpc.map(select)),rows(live.functions.map(select)));
const names=fs.readdirSync('supabase/functions').filter(n=>fs.existsSync(`supabase/functions/${n}/index.ts`));
const calls=s=>[...new Set([...s.matchAll(/\.rpc\(\s*['"]([^'"]+)['"]/g)].map(m=>m[1]))].sort();
const from=s=>[...new Set([...s.matchAll(/\.from\(\s*['"]([^'"]+)['"]/g)].map(m=>m[1]))].sort();
const inventory=edges.map(edge=>{
 const candidates=edge.files.filter(f=>path.basename(f.name)==='index.ts');
 if(candidates.length!==1)throw Error('Entrypoint ambiguo: '+edge.name);
 const remote=candidates[0].content,local=fs.readFileSync(`supabase/functions/${edge.name}/index.ts`,'utf8');
 return {nombre:edge.name,version:edge.version,verify_jwt:edge.verify_jwt,
  sha256_publicado:sha(remote),sha256_local:sha(local),mismo_contenido:remote===local,
  rpc_publicadas:calls(remote),rpc_locales:calls(local),tablas_publicadas:from(remote),tablas_locales:from(local),
  guard_local:local.includes('serveEvento('),asignacion_directa_publicada:remote.includes('usuarios_eventos'),
  // Static indicators require manual interpretation, not proof of authorization.
  observacion:'Comparación estática; revisar contratos y dependencias antes de publicar.'};
});
const result={proyecto:'rkjlqxxmxbiciuhtpnpf',fecha_utc:new Date().toISOString(),alcance:'Solo catálogo y código; sin filas reales, secretos o invocaciones de negocio.',
 catalogo_coincide:Object.values(structure).every(d=>!d.faltan.length&&!d.adicionales.length),comparacion_catalogo:structure,
 edge:inventory,solo_local:names.filter(n=>!edges.some(e=>e.name===n)).sort(),
 solo_publicado:edges.map(e=>e.name).filter(n=>!names.includes(n)),
 limites:'La revisión estática no prueba Auth/Storage/Vault ni el frontend publicado. No acredita ausencia de vulnerabilidades.'};
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');
console.log(`Catálogo coincide: ${result.catalogo_coincide}; ${inventory.length} Edge publicadas revisadas; ${result.solo_local.length} solo locales.`);
