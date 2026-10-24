// Real embedded PostgreSQL (PGlite 0.5.11); synthetic schema/data, no Supabase/Vault service.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const R='43e67bda-d19d-4c0e-a639-e85f2d62f294', C='3dc92160-79af-4bf7-b770-263038e88900';
const U='aa111111-1111-4111-8111-111111111111', V='aa222222-2222-4222-8222-222222222222';
const RR='bb111111-1111-4111-8111-111111111111', RC='bb222222-2222-4222-8222-222222222222';
const PR='cc111111-1111-4111-8111-111111111111', PC='cc222222-2222-4222-8222-222222222222';
let count=0;
const scalar=async(sql,args=[]) => (await db.query(sql,args)).rows[0].v;
const fail=async(sql,args,pattern)=>{await assert.rejects(db.query(sql,args),pattern);count++;};
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
    CREATE SCHEMA auth;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.uid',true),'')::uuid $$;
    CREATE TABLE usuarios(id uuid PRIMARY KEY,rol text,activo boolean);
    CREATE TABLE usuarios_eventos(usuario_id uuid,evento_id uuid,activo boolean,PRIMARY KEY(usuario_id,evento_id));
    CREATE TABLE promotoras(id uuid PRIMARY KEY,nombres text,apellidos text,telefono_whatsapp text,foto_path text);
    CREATE TABLE asesores(id uuid PRIMARY KEY,nombre text);
    CREATE TABLE registros(id uuid PRIMARY KEY,evento_id uuid,estado text,exento_pago boolean DEFAULT false,folio text,created_at timestamptz DEFAULT now(),promotora_id uuid,asesor_id uuid);
    CREATE TABLE pagos(id uuid PRIMARY KEY,registro_id uuid,estado text,importe numeric,referencia text,created_at timestamptz DEFAULT now(),comprobante_path text,validado_por uuid,validado_at timestamptz);
    CREATE TABLE invitaciones(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),registro_id uuid,token_hash text,token_vault_id uuid,estado text,emitida_por uuid,emitida_at timestamptz,revocada_at timestamptz);
    CREATE TABLE accesos(id uuid PRIMARY KEY,invitacion_id uuid,operador_id uuid,ingresado_at timestamptz);
    CREATE TABLE auditoria(id uuid DEFAULT gen_random_uuid(),usuario_id uuid,accion text,entidad text,entidad_id uuid,detalles jsonb);
    INSERT INTO usuarios VALUES('${U}','administrador',true),('${V}','validador',true);
    INSERT INTO usuarios_eventos VALUES('${U}','${R}',true),('${U}','${C}',true),('${V}','${R}',true);
    INSERT INTO registros(id,evento_id,estado,folio) VALUES('${RR}','${R}','pendiente','R-1'),('${RC}','${C}','pendiente','C-1');
    INSERT INTO pagos(id,registro_id,estado,importe) VALUES('${PR}','${RR}','pendiente',300),('${PC}','${RC}','pendiente',300);
  `);
  for (const file of ['sql/security/radevs_administracion_propuesta.sql','sql/security/radevs_personal_propuesta.sql',
    'sql/chiapas/funciones_administrativas_chiapas_propuesta.sql','sql/security/radevs_bandejas_propuesta.sql','sql/chiapas/bandejas_admin_chiapas_paginadas_propuesta.sql','sql/security/qr_eventos_propuesta.sql']) {
    let sql=fs.readFileSync(file,'utf8');
    // Production-definition hashes cannot match an empty synthetic database.
    // Only the preflight DO is omitted; executable function bodies and ACLs remain exact.
    sql=sql.replace(/DO \$verificacion\$[\s\S]*?\$verificacion\$;/g,'').replace(/DO \$verificar_version\$[\s\S]*?\$verificar_version\$;/g,'');
    await db.exec(sql); count++;
  }
  const bandeja=await scalar('select bandejas_admin_paginadas($1,1,$2,$3) v',['pagos','',U]);
  assert.equal(bandeja.total,1);assert.equal(bandeja.registros[0].registro_id,RR);count++;
  const chiapas=await scalar('select bandejas_admin_chiapas_paginadas($1,1,$2,$3) v',['pagos','',U]);
  assert.equal(chiapas.total,1);assert.equal(chiapas.registros[0].registro_id,RC);count++;
  await fail('select validar_pago_admin($1,$2,null,$3)',[PC,'aprobar',U],/exclusiva de RADEVS/i);
  await db.query('update usuarios_eventos set activo=false where usuario_id=$1 and evento_id=$2',[U,R]);
  await fail('select validar_pago_admin($1,$2,null,$3)',[PR,'aprobar',U],/asignacion activa/i);
  await fail('select bandejas_admin_paginadas($1,1,$2,$3)',['pagos','',U],/asignacion activa/i);
  await db.query('update usuarios_eventos set activo=true where usuario_id=$1',[U]);
  await db.query("select set_config('test.uid',$1,false)",[V]);
  await fail('select validar_pago_personal($1,$2,null)',[PC,'aprobar'],/otro evento/i);
  await db.query('update usuarios_eventos set activo=false where usuario_id=$1',[V]);
  await fail('select validar_pago_personal($1,$2,null)',[PR,'aprobar'],/asignacion activa/i);
  await db.query("select set_config('test.uid',$1,false)",[U]);
  const token='a'.repeat(64);
  await db.query(`update registros set estado='confirmado',exento_pago=true where id=$1`,[RR]);
  await db.query(`insert into invitaciones(registro_id,token_hash,estado) values($1,encode(sha256(convert_to($2,'UTF8')),'hex'),'emitida')`,[RR,token]);
  let ficha=await scalar('select consultar_qr_acceso_evento($1,$2) v',[token,C]);
  assert.equal(ficha.ok,false);count++;
  ficha=await scalar('select registrar_entrada_qr_evento($1,$2) v',[token,C]);
  assert.equal(ficha.ok,false);assert.equal(await scalar('select count(*)::int v from accesos'),0);count++;
  ficha=await scalar('select consultar_qr_acceso_evento($1,$2) v',[token,R]);
  assert.equal(ficha.estado,'autorizable');count++;
  ficha=await scalar('select registrar_entrada_qr_evento($1,$2) v',[token,R]);
  assert.equal(ficha.estado,'ingreso_registrado');count++;
  ficha=await scalar('select registrar_entrada_qr_evento($1,$2) v',[token,R]);
  assert.equal(ficha.estado,'ya_ingreso');assert.equal(await scalar('select count(*)::int v from accesos'),1);count++;
  await fail('select validar_pago_admin_chiapas($1,$2,null,$3)',[PR,'aprobar',U],/Chiapas|evento/i);
  await db.exec('BEGIN');
  await db.query('select validar_pago_admin_chiapas($1,$2,$3,$4)',[PC,'rechazar','Comprobante de prueba incorrecto',U]);
  assert.equal(await scalar('select estado v from pagos where id=$1',[PC]),'rechazado');count++;
  await db.exec('ROLLBACK');
  await db.query('update usuarios set activo=false where id=$1',[U]);
  await fail('select consultar_qr_acceso_evento($1,$2)',[token,R],/no autorizado/i);
  assert.equal(await scalar('select count(*)::int v from pagos where estado=\'pendiente\''),2);count++;
  // Exercise actual restrictive RLS against deliberately permissive fixture policies.
  await db.exec(`
    CREATE SCHEMA storage;
    CREATE TABLE storage.buckets(id text PRIMARY KEY,public boolean);
    CREATE TABLE storage.objects(id uuid DEFAULT gen_random_uuid(),bucket_id text,name text);
    INSERT INTO storage.buckets VALUES('comprobantes-pago',true),('fotos-promotoras',true);
    INSERT INTO storage.objects(bucket_id,name) VALUES('comprobantes-pago','radevs.png'),('comprobantes-pago','chiapas.png');
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
    CREATE POLICY fixture_storage_allow ON storage.objects FOR SELECT TO authenticated,anon USING(true);
    GRANT USAGE ON SCHEMA public,auth,storage TO authenticated,anon;
    GRANT SELECT ON ALL TABLES IN SCHEMA public,storage TO authenticated,anon;
    GRANT INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public,storage TO authenticated;
  `);
  await db.query('update pagos set comprobante_path=$1 where id=$2',['radevs.png',PR]);
  await db.query('update pagos set comprobante_path=$1 where id=$2',['chiapas.png',PC]);
  for (const table of ['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria']) {
    await db.exec(`CREATE POLICY fixture_allow ON ${table} FOR SELECT TO authenticated,anon USING(true)`);
  }
  await db.exec(fs.readFileSync('sql/security/rls_storage_propuesta.sql','utf8'));count++;
  await db.query('update usuarios set activo=true where id=$1',[V]);
  await db.query('update usuarios_eventos set activo=true where usuario_id=$1',[V]);
  await db.query("select set_config('test.uid',$1,false)",[V]);
  await db.exec('SET ROLE authenticated');
  assert.equal(await scalar('select count(*)::int v from registros'),1);count++;
  assert.equal(await scalar('select count(*)::int v from pagos'),1);count++;
  assert.equal(await scalar("select count(*)::int v from storage.objects where name='chiapas.png'"),0);count++;
  assert.equal(await scalar("select count(*)::int v from storage.objects where name='radevs.png'"),1);count++;
  assert.equal((await db.query("update usuarios set rol='administrador' where id=$1 returning id",[V])).rows.length,0);count++;
  await fail('insert into usuarios_eventos values($1,$2,true)',[V,C],/row.level security/i);
  assert.equal((await db.query("update storage.objects set name='copiado.png' returning id")).rows.length,0);count++;
  await db.exec('SET ROLE anon');
  assert.equal(await scalar('select count(*)::int v from registros'),0);count++;
  assert.equal(await scalar('select count(*)::int v from storage.objects'),0);count++;
  await db.exec('RESET ROLE');
  await db.exec(fs.readFileSync('sql/security/rollback_rls_storage.sql','utf8'));count++;
  console.log(`${count} comprobaciones SQL aprobadas en PostgreSQL embebido. Esquema y datos sintéticos; sin Vault ni Supabase real.`);
} finally { await db.close(); }
