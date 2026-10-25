import fs from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
export const catalogo = JSON.parse(fs.readFileSync('tests/fixtures/catalogo_esquema_20261024.json','utf8'));
export const funciones = JSON.parse(fs.readFileSync('tests/fixtures/catalogo_rpc_20261024.json','utf8'));
const qi = name => '"'+name.replaceAll('"','""')+'"';
/** Actual public-schema structure, never production rows. Auth/Storage/Vault APIs
 * are local adapters. Vault adapter uses real pgcrypto encryption, not Supabase Vault.
 */
export async function crearBaseCatalogo() {
 const db=new PGlite({ extensions:{pgcrypto} });
 await db.exec(`CREATE EXTENSION pgcrypto;
  CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
  CREATE SCHEMA auth; CREATE SCHEMA vault; CREATE SCHEMA storage;
  CREATE TABLE auth.users(id uuid PRIMARY KEY);
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.role',true),'') $$;
  CREATE TABLE storage.buckets(id text PRIMARY KEY,public boolean);
  CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text,name text);
  ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
  CREATE TABLE vault.fixture_secrets(id uuid PRIMARY KEY,encrypted bytea);
  CREATE FUNCTION vault.create_secret(text,text,text,uuid) RETURNS uuid LANGUAGE plpgsql AS $$
   DECLARE v_id uuid:=gen_random_uuid(); BEGIN
    INSERT INTO vault.fixture_secrets VALUES(v_id,public.pgp_sym_encrypt($1,current_setting('fixture.vault_key')));
    RETURN v_id; END $$;
  CREATE VIEW vault.decrypted_secrets AS SELECT id,pgp_sym_decrypt(encrypted,current_setting('fixture.vault_key')) decrypted_secret FROM vault.fixture_secrets;
  GRANT USAGE ON SCHEMA public,auth,storage TO anon,authenticated,service_role;
 `);
 await db.query("select set_config('fixture.vault_key',$1,false)",[crypto.randomUUID()]);
 for (const table of catalogo.tables) {
  const columns=catalogo.columns.filter(c=>c.tabla===table.nombre).map(c=>`${qi(c.nombre)} ${c.tipo}${c.identidad?' GENERATED '+(c.identidad==='a'?'ALWAYS':'BY DEFAULT')+' AS IDENTITY':''}${c.defecto?' DEFAULT '+c.defecto:''}${c.not_null?' NOT NULL':''}`);
  await db.exec(`CREATE TABLE public.${qi(table.nombre)} (${columns.join(',')})`);
 }
 for(const constraint of [...catalogo.constraints].sort((a,b)=>(a.tipo==='f')-(b.tipo==='f'))) {
  await db.exec(`ALTER TABLE public.${qi(constraint.tabla)} ADD CONSTRAINT ${qi(constraint.nombre)} ${constraint.definicion}`);
 }
 for(const index of catalogo.indexes) {
  if(!catalogo.constraints.some(c=>c.nombre===index.indexname)) await db.exec(index.indexdef);
 }
 for(const fn of funciones) {
  await db.exec(fn.definicion);
  // NULL proacl means PostgreSQL defaults (owner + PUBLIC); preserve it exactly.
  if(fn.acl===null)continue;
  const sig='public.'+fn.firma;
  await db.exec(`REVOKE ALL ON FUNCTION ${sig} FROM PUBLIC,anon,authenticated,service_role`);
  if(fn.acl)for(const role of ['anon','authenticated','service_role']) {
   if(fn.acl.includes(role+'=X/')) await db.exec(`GRANT EXECUTE ON FUNCTION ${sig} TO ${role}`);
  }
 }
 for(const trigger of catalogo.triggers)await db.exec(trigger.definicion);
 for(const table of catalogo.tables) {
  if(table.rls)await db.exec(`ALTER TABLE public.${qi(table.nombre)} ENABLE ROW LEVEL SECURITY`);
  await db.exec(`REVOKE ALL ON public.${qi(table.nombre)} FROM PUBLIC,anon,authenticated,service_role`);
  for(const role of ['anon','authenticated','service_role']) {
   const letters=table.acl?.match(new RegExp(role+'=([^/]*)/'))?.[1]||'';
   const perms=Object.entries({a:'INSERT',r:'SELECT',w:'UPDATE',d:'DELETE',D:'TRUNCATE',x:'REFERENCES',t:'TRIGGER',m:'MAINTAIN'}).filter(([letter])=>letters.includes(letter)).map(([,perm])=>perm);
   if(perms.length) await db.exec(`GRANT ${perms.join(',')} ON public.${qi(table.nombre)} TO ${role}`);
  }
 }
 for(const p of catalogo.policies) {
  await db.exec(`CREATE POLICY ${qi(p.policyname)} ON ${qi(p.schemaname)}.${qi(p.tablename)} AS ${p.permissive} FOR ${p.cmd} TO ${p.roles.map(qi).join(',')}${p.qual?' USING ('+p.qual+')':''}${p.with_check?' WITH CHECK ('+p.with_check+')':''}`);
 }
 for(const b of catalogo.buckets)await db.query('insert into storage.buckets values($1,$2)',[b.id,b.public]);
 return db;
}
