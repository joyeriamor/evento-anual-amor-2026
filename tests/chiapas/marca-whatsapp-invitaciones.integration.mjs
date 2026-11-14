import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
try {
await db.exec(`
create role anon; create role authenticated; create role service_role;
create schema auth;
create function auth.uid() returns uuid language sql as 'select null::uuid';
create table usuarios(id uuid, rol text, activo boolean);
create table usuarios_eventos(usuario_id uuid,evento_id uuid,activo boolean);
create table promotoras(id uuid,nombres text,apellidos text,telefono_whatsapp text);
create table asesores(id uuid,nombre text);
create table registros(id uuid, folio text, evento_id uuid, promotora_id uuid, asesor_id uuid, estado text, exento_pago boolean, created_at timestamptz);
create table invitaciones(id uuid,registro_id uuid,estado text,emitida_at timestamptz);
create table pagos(id uuid,registro_id uuid,estado text,importe numeric,referencia text,created_at timestamptz);
`);
await db.exec(await readFile(process.argv[2], 'utf8'));
const eventos = [
  ['bandejas_admin_paginadas','43e67bda-d19d-4c0e-a639-e85f2d62f294'],
  ['bandejas_admin_chiapas_paginadas','3dc92160-79af-4bf7-b770-263038e88900']
];
for (const [fn, evento] of eventos) {
  const admin = (await db.query("insert into usuarios values(gen_random_uuid(),'administrador',true) returning id")).rows[0].id;
  await db.query('insert into usuarios_eventos values ($1,$2,true)',[admin,evento]);
  await db.query(`insert into registros select gen_random_uuid(), 'F-'||n, $1, null,null,'confirmado',false,now()
    from generate_series(1,25) n`,[evento]);
  await db.query(`insert into invitaciones select gen_random_uuid(),id,
    case when folio='F-23' then 'revocada' when folio='F-22' then 'activa' else 'emitida' end,now()
    from registros where evento_id=$1 and folio not in ('F-24','F-25')`,[evento]);
  await db.query("insert into pagos select gen_random_uuid(),id,'pendiente',300,null,now() from registros where evento_id=$1 and folio='F-1'",[evento]);
  const consultar=async(tipo,pagina=1,busqueda='')=>(await db.query(`select public.${fn}($1,$2,$3,$4) as r`,[tipo,pagina,busqueda,admin])).rows[0].r;
  const fila=(await consultar('invitaciones_emitidas',1,'F-22')).registros[0];
  const marcar=async(id,estado,ev=evento)=>(await db.query('select public.marcar_whatsapp_invitacion_manual($1,$2,$3,$4) as r',[ev,admin,id,estado])).rows[0].r;
  assert.equal(fila.whatsapp_enviada_manual,false);
  assert.equal(await marcar(fila.invitacion_id,true),true);
  assert.equal((await consultar('invitaciones_emitidas',1,'F-22')).registros[0].whatsapp_enviada_manual,true);
  assert.equal(await marcar(fila.invitacion_id,false),true);
  assert.equal((await consultar('invitaciones_emitidas',1,'F-22')).registros[0].whatsapp_enviada_manual,false);
  const revocada=(await consultar('invitaciones',1,'F-23')).registros[0];
  assert.equal(await marcar(revocada.invitacion_id,true),false);
  assert.equal(await marcar(fila.invitacion_id,true,eventos.find(([,id])=>id!==evento)[1]),false);
  assert.equal(await marcar(fila.invitacion_id,null),false);
  await db.query('update usuarios_eventos set activo=false where usuario_id=$1',[admin]);
  assert.equal(await marcar(fila.invitacion_id,true),false);
}
await db.exec(await readFile(process.argv[3], 'utf8'));
assert.equal((await db.query("select to_regprocedure('public.marcar_whatsapp_invitacion_manual(uuid,uuid,uuid,boolean)') is null as retirada")).rows[0].retirada,true);
console.log('19 comprobaciones SQL con datos ficticios, incluida reversión.');
} finally { await db.close(); }
