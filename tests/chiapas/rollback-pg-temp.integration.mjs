import assert from 'node:assert/strict';
import fs from 'node:fs';
import { crearBaseCatalogo,catalogo } from './base-catalogo.mjs';
const sql=fs.readFileSync('sql/security/ensayo_multievento_pg_temp_rollback.sql','utf8');
for(const re of [
 /\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM|TRUNCATE|ALTER\s+TABLE)\s+(?:public|auth|storage|vault)\./i,
 /\bCREATE(?:\s+OR\s+REPLACE)?\s+FUNCTION\s+(?:public|auth|storage|vault)\./i,
 /\bEXECUTE\s+FUNCTION\s+(?!pg_temp\.)[a-z_]/i,
 /\bvault\.(?:create_secret|decrypted_secrets)\b/i,
 /'evento-anual-'/i,
]) assert.equal(re.test(sql),false,`Referencia sin aislar: ${re}`);
assert.match(sql,/ROLLBACK;\s*SELECT 'APROBADO'/);
const db=await crearBaseCatalogo();
try {
 const before=(await db.query("select p.oid::regprocedure::text firma,md5(pg_get_functiondef(p.oid)) hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' order by p.oid")).rows;
 const result=(await db.exec(sql)).at(-1).rows[0];
 assert.equal(result.resultado,'APROBADO');assert.equal(result.casos,31);assert.equal(result.rollback_sin_tablas_de_ensayo,true);
 for(const table of catalogo.tables)assert.equal((await db.query(`select count(*)::int total from public."${table.nombre}"`)).rows[0].total,0,table.nombre);
 const after=(await db.query("select p.oid::regprocedure::text firma,md5(pg_get_functiondef(p.oid)) hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' order by p.oid")).rows;
 assert.deepEqual(after,before);
 assert.equal((await db.query("select to_regprocedure('pg_temp.validar_pago_admin(uuid,text,text,uuid)') is null limpio")).rows[0].limpio,true);
 console.log('31 casos pg_temp aprobados y ROLLBACK verificado; tablas/funciones public intactas.');
}catch(e){console.error(e.message,e.where||'');process.exitCode=1;}finally{await db.close();}
