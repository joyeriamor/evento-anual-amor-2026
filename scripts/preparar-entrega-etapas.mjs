// Local review packages only. No network, CLI push or deployment.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { crearBaseCatalogo } from '../tests/chiapas/base-catalogo.mjs';
const dir='sql/entrega_por_etapas';
fs.mkdirSync(dir,{recursive:true});
const stages=[
 ['01_chiapas',[
  'sql/chiapas/emitir_invitacion_chiapas_interna.sql',
  'sql/chiapas/validar_pago_personal_chiapas_qr_integrado.sql',
  'sql/chiapas/funciones_administrativas_chiapas_propuesta.sql',
  'sql/chiapas/bandejas_admin_chiapas_paginadas_propuesta.sql']],
 ['02_compartidos',[
  'sql/security/qr_eventos_propuesta.sql','sql/security/perfiles_evento_propuesta.sql',
  'sql/security/registro_multievento_propuesta.sql','sql/security/rls_storage_propuesta.sql']],
 ['03_protecciones_radevs',[
  'sql/security/radevs_administracion_propuesta.sql','sql/security/radevs_personal_propuesta.sql',
  'sql/security/radevs_bandejas_propuesta.sql','sql/chiapas/qr_legacy_compatibilidad.sql']],
];
const literal=s=>"'"+s.replaceAll("'","''")+"'";
const clean=s=>s.replace(/^BEGIN;\s*/m,'').replace(/COMMIT;\s*$/,'')
 .replace(/DO \$(verificacion|verificar_version|control|comprobacion)\$[\s\S]*?\$\1\$;/g,'');
async function snapshot(db){return (await db.query(`select 'public.'||quote_ident(p.proname)||'('||oidvectortypes(p.proargtypes)||')' as sig,pg_get_functiondef(p.oid) as def,
 md5(pg_get_functiondef(p.oid)) as hash,p.proacl::text as acl
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' order by p.oid`)).rows;}
function guard(rows,absent=[]){return `DO $stage_guard$ BEGIN\n`+rows.map(f=>`IF to_regprocedure(${literal(f.sig)}) IS NULL OR md5(pg_get_functiondef(to_regprocedure(${literal(f.sig)}))) IS DISTINCT FROM ${literal(f.hash)} OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure(${literal(f.sig)})) IS DISTINCT FROM ${f.acl===null?'NULL':literal(f.acl)} THEN RAISE EXCEPTION 'Drift: ${f.sig}'; END IF;`).join('\n')+'\n'+absent.map(f=>`IF to_regprocedure(${literal(f.sig)}) IS NOT NULL THEN RAISE EXCEPTION 'Already exists: ${f.sig}'; END IF;`).join('\n')+'\nEND; $stage_guard$;\n';}
function restore(f){if(f.acl===null)return f.def+';\n';let sql=f.def+';\n'+`REVOKE ALL ON FUNCTION ${f.sig} FROM PUBLIC,anon,authenticated,service_role;\n`;
 if(f.acl===null||/(?:\{|,)=X\//.test(f.acl))sql+=`GRANT EXECUTE ON FUNCTION ${f.sig} TO PUBLIC;\n`;
 for(const role of ['anon','authenticated','service_role'])if(f.acl?.includes(role+'=X/'))sql+=`GRANT EXECUTE ON FUNCTION ${f.sig} TO ${role};\n`;
 return sql;}
const db=await crearBaseCatalogo();const manifest=[];
try{
 for(const [name,sources] of stages){
  const before=await snapshot(db);
  const body=sources.map(file=>'-- Source: '+file+'\n'+clean(fs.readFileSync(file,'utf8'))).join('\n');
  await db.exec('BEGIN;\n'+body+'\nCOMMIT;');
  const after=await snapshot(db),old=new Map(before.map(f=>[f.sig,f]));
  const changed=after.filter(f=>!old.has(f.sig)||old.get(f.sig).hash!==f.hash||old.get(f.sig).acl!==f.acl);
  const added=changed.filter(f=>!old.has(f.sig));
  if(name==='01_chiapas')assert.ok(changed.every(f=>f.sig.includes('chiapas')),'Chiapas stage may only change Chiapas functions');
  const header='-- REVIEW ONLY. Requires separate explicit production approval.\n-- Alternative to the consolidated migration: NEVER apply both routes.\n';
  fs.writeFileSync(`${dir}/${name}.sql`,header+'BEGIN;\n'+guard(changed.filter(f=>old.has(f.sig)).map(f=>old.get(f.sig)),added)+body+'\nCOMMIT;\n');
  let rollback=header+'BEGIN;\n'+guard(changed);
  for(const f of changed.filter(f=>old.has(f.sig)))rollback+=restore(old.get(f.sig));
  for(const f of [...added].reverse())rollback+=`DROP FUNCTION public.${f.sig};\n`.replace('public.public.','public.');
  if(name==='02_compartidos'){
   rollback+=clean(fs.readFileSync('sql/security/rollback_rls_storage.sql','utf8'))+'\n';
   const full=fs.readFileSync('sql/security/rollback_eventos_completo.sql','utf8');
   const tail=full.slice(full.indexOf('ALTER TABLE public.'));
   assert.ok(tail.startsWith('ALTER TABLE public.'),'Missing rollback structural tail');
   rollback+=tail.replace(/COMMIT;\s*$/,'');
  }
  rollback+='COMMIT;\n';fs.writeFileSync(`${dir}/${name}_rollback.sql`,rollback);
  manifest.push({etapa:name,fuentes:sources,funciones:changed.map(f=>({firma:f.sig,nueva:!old.has(f.sig),hash_anterior:old.get(f.sig)?.hash??null,hash_posterior:f.hash}))});
 }
 fs.writeFileSync(`${dir}/manifest.json`,JSON.stringify(manifest,null,2)+'\n');
 console.log('Tres etapas y sus rollback generados localmente. Sin conexión a producción.');
}finally{await db.close();}
