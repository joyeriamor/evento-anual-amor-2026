import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
try {
await db.exec(`
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
  const primera=await consultar('invitaciones_emitidas');
  const segunda=await consultar('invitaciones_emitidas',2);
  assert.equal(primera.total,22);
  assert.equal(primera.registros.length,20);
  assert.equal(segunda.registros.length,2);
  assert.equal(new Set([...primera.registros,...segunda.registros].map(f=>f.registro_id)).size,22);
  assert.ok([...primera.registros,...segunda.registros].every(f=>['activa','emitida'].includes(f.invitacion_estado)));
  assert.equal((await consultar('invitaciones_emitidas',1,'F-22')).registros[0].invitacion_estado,'activa');
  assert.equal((await consultar('invitaciones_emitidas',1,'F-23')).total,0);
  assert.equal((await consultar('invitaciones')).total,25);
  assert.equal((await consultar('pagos')).total,1);
  const otra = eventos.find(([nombre])=>nombre!==fn)[0];
  await assert.rejects(db.query(`select public.${otra}('invitaciones_emitidas',1,'',$1)`,[admin]), /asignacion activa/);
}
await db.exec(await readFile(process.argv[3], 'utf8'));
const admin=(await db.query('select usuario_id from usuarios_eventos limit 1')).rows[0].usuario_id;
await assert.rejects(db.query("select public.bandejas_admin_paginadas('invitaciones_emitidas',1,'',$1)",[admin]),/Tipo de bandeja invalido/);
console.log('21 comprobaciones SQL con datos ficticios, incluida reversión.');
} finally { await db.close(); }
