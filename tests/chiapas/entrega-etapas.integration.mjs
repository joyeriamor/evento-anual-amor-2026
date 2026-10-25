// Real embedded PostgreSQL; reconstructed catalog, no remote services or real rows.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { crearBaseCatalogo } from './base-catalogo.mjs';
const dir='sql/entrega_por_etapas';
const packageRoot=process.argv[2];
const stages=packageRoot?JSON.parse(fs.readFileSync(`${packageRoot}/manifest.json`,'utf8')).archivos:JSON.parse(fs.readFileSync(`${dir}/manifest.json`,'utf8'));
const readStage=(stage,rollback=false)=>fs.readFileSync(packageRoot
 ?`${packageRoot}/${rollback?'rollback/'+stage.rollback:'migrations/'+stage.migracion}`
 :`${dir}/${stage.etapa}${rollback?'_rollback':''}.sql`,'utf8');
async function state(db){const result={};for(const [key,sql] of Object.entries({
 funciones:`select p.oid::regprocedure::text firma,md5(pg_get_functiondef(p.oid)) hash,p.proacl::text acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' order by 1`,
 politicas:`select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check from pg_policies where schemaname in ('public','storage') order by 1,2,3`,
 tablas:`select c.relname,c.relrowsecurity,c.relforcerowsecurity,c.relacl::text from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' order by 1`,
 buckets:'select * from storage.buckets order by id',
 datos:`select (select count(*) from registros)::int registros,(select count(*) from eventos)::int eventos,(select count(*) from auth.users)::int usuarios`
}))result[key]=(await db.query(sql)).rows;return result;}
const split=await crearBaseCatalogo(),combined=await crearBaseCatalogo();let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++};
try{
 const initial=await state(split),before=[];
 for(const stage of stages){
  before.push(await state(split));
  await split.exec(readStage(stage));
  const current=await state(split);eq(current.datos,initial.datos);
  if(stage.etapa==='01_chiapas'){
   eq(current.funciones.filter(f=>!f.firma.includes('chiapas')),initial.funciones);
   for(const key of ['politicas','tablas','buckets'])eq(current[key],initial[key]);
   eq(packageRoot?JSON.parse(fs.readFileSync(`${dir}/manifest.json`,'utf8'))[0].funciones.length:stage.funciones.length,6);
  }
 }
 const migration=fs.readdirSync('supabase/migrations').find(f=>f.endsWith('_aislar_eventos_radevs_chiapas.sql'));
 await combined.exec(fs.readFileSync(`supabase/migrations/${migration}`,'utf8'));
 eq(await state(split),await state(combined));
 for(let i=stages.length-1;i>=0;i--){
  await split.exec(readStage(stages[i],true));
  eq(await state(split),before[i]);
 }
 eq(await state(split),initial);
 // Applying an already-installed stage must fail before any effects.
 const first=readStage(stages[0]);
 await split.exec(first);const installed=await state(split);
 await assert.rejects(split.exec(first),/Already exists/);checks++;
 await split.exec('ROLLBACK');eq(await state(split),installed);
 // A drifted existing function blocks stage 3 atomically.
 await split.exec(readStage(stages[1]));
 await split.exec(`CREATE OR REPLACE FUNCTION public.consultar_qr_acceso(p_token text) RETURNS jsonb LANGUAGE sql AS $$select '{}'::jsonb$$`);
 const drifted=await state(split);
 await assert.rejects(split.exec(readStage(stages[2])),/Drift/);checks++;
 await split.exec('ROLLBACK');eq(await state(split),drifted);
 console.log(`${checks} comprobaciones aprobadas: etapas equivalentes, Chiapas sin cambios a recursos existentes, rollback exacto y rechazo de drift. PostgreSQL local; ningún servicio remoto.`);
}finally{await split.close();await combined.close();}
