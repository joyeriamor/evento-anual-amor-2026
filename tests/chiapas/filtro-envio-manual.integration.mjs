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
    create table registros(id uuid,folio text,evento_id uuid,promotora_id uuid,asesor_id uuid,estado text,exento_pago boolean,created_at timestamptz);
    create table invitaciones(id uuid,registro_id uuid,estado text,emitida_at timestamptz,whatsapp_enviada_manual boolean);
    create table pagos(id uuid,registro_id uuid,estado text,importe numeric,referencia text,created_at timestamptz);
  `);
  await db.exec(await readFile('supabase/migrations/20261117013505_orden_invitaciones_fecha_emision.sql', 'utf8'));
  await db.exec(await readFile('supabase/migrations/20261125155422_filtro_envio_manual_invitaciones.sql', 'utf8'));
  const eventos = [
    ['bandejas_admin_paginadas', '43e67bda-d19d-4c0e-a639-e85f2d62f294'],
    ['bandejas_admin_chiapas_paginadas', '3dc92160-79af-4bf7-b770-263038e88900'],
  ];
  for (const [fn, evento] of eventos) {
    const admin = (await db.query("insert into usuarios values(gen_random_uuid(),'administrador',true) returning id")).rows[0].id;
    await db.query('insert into usuarios_eventos values($1,$2,true)', [admin, evento]);
    await db.query(`insert into registros select gen_random_uuid(),'F-'||n,$1,null,null,'confirmado',false,now() from generate_series(1,48) n`, [evento]);
    await db.query(`insert into invitaciones
      select gen_random_uuid(),id,case when folio='F-46' then 'revocada' when folio='F-45' then 'activa' else 'emitida' end,
      now() + substring(folio from 3)::integer * interval '1 minute',
      case when substring(folio from 3)::integer % 3 = 0 then true
           when substring(folio from 3)::integer % 3 = 1 then false else null end
      from registros where evento_id=$1 and folio not in ('F-47','F-48')`, [evento]);
    // A revoked historical invitation must not replace the active invitation.
    await db.query(`insert into invitaciones select gen_random_uuid(),id,'revocada',now()+interval '1 day',true
      from registros where evento_id=$1 and folio='F-1'`, [evento]);
    await db.query("insert into pagos select gen_random_uuid(),id,'pendiente',300,null,now() from registros where evento_id=$1 and folio='F-1'", [evento]);
    const consultar = async (tipo, envio=null, pagina=1, busqueda='') =>
      (await db.query(`select public.${fn}($1,$2,$3,$4,$5) as r`, [tipo,pagina,busqueda,admin,envio])).rows[0].r;
    assert.equal((await consultar('invitaciones')).total, 48);
    assert.equal((await consultar('invitaciones_emitidas')).total, 45);
    for (const tipo of ['invitaciones', 'invitaciones_emitidas']) {
      for (const [envio, cantidad] of [['enviadas',15], ['por_enviar',30]]) {
        const a = await consultar(tipo,envio);
        const b = await consultar(tipo,envio,2);
        const filas = [...a.registros,...b.registros];
        assert.equal(a.total,cantidad);
        assert.equal(filas.length,cantidad);
        assert.equal(new Set(filas.map(f=>f.registro_id)).size,cantidad);
        assert.ok(filas.every(f=>['emitida','activa'].includes(f.invitacion_estado)));
        assert.ok(filas.every(f=>f.whatsapp_enviada_manual === (envio==='enviadas')));
        assert.ok(filas.every((f,i)=>i===0 || new Date(filas[i-1].fecha)>=new Date(f.fecha)));
      }
    }
    assert.equal((await consultar('invitaciones_emitidas','por_enviar',1,'F-1')).total,8);
    const antes = await consultar('invitaciones_emitidas','enviadas');
    await db.query("update invitaciones set whatsapp_enviada_manual=true where registro_id in (select id from registros where evento_id=$1 and folio='F-1') and estado='emitida'", [evento]);
    assert.equal((await consultar('invitaciones_emitidas','enviadas')).total,antes.total+1);
    assert.equal((await consultar('invitaciones_emitidas','por_enviar')).total,29);
    assert.equal((await consultar('pagos')).total,1);
    await assert.rejects(consultar('pagos','enviadas'),/Estado de envio manual invalido/);
    await assert.rejects(consultar('invitaciones','otro'),/Estado de envio manual invalido/);
    const otra = eventos.find(([nombre])=>nombre!==fn)[0];
    await assert.rejects(db.query(`select public.${otra}('invitaciones',1,'',$1,'enviadas')`, [admin]),/asignacion activa/);
    await db.query('update usuarios_eventos set activo=false where usuario_id=$1', [admin]);
    await assert.rejects(consultar('invitaciones','enviadas'),/asignacion activa/);
    await db.query('update usuarios_eventos set activo=true where usuario_id=$1', [admin]);
    await db.query('update usuarios set activo=false where id=$1', [admin]);
    await assert.rejects(consultar('invitaciones','enviadas'),/Administrador no autorizado/);
  }
  await db.exec(await readFile('supabase/rollbacks/20261125155422_filtro_envio_manual_invitaciones.sql','utf8'));
  assert.equal((await db.query("select count(*)::integer as n from pg_proc where proname in ('bandejas_admin_paginadas','bandejas_admin_chiapas_paginadas') and pronargs=5")).rows[0].n,0);
  assert.equal((await db.query("select count(*)::integer as n from pg_proc where proname in ('bandejas_admin_paginadas','bandejas_admin_chiapas_paginadas') and pronargs=4")).rows[0].n,2);
  console.log('Filtro SQL: combinación, conteo, paginación, marcas, orden, aislamiento y rollback correctos para ambos eventos (datos locales ficticios).');
} finally {
  await db.close();
}
