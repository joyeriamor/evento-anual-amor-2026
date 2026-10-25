// Real PostgreSQL + pgcrypto, exact read-only public-schema catalog, fictitious rows.
// Auth, storage and Vault interfaces are LOCAL ADAPTERS, not Supabase services.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { crearBaseCatalogo,funciones,catalogo } from './base-catalogo.mjs';
const db=await crearBaseCatalogo();let checks=0;
const R='43e67bda-d19d-4c0e-a639-e85f2d62f294',C='3dc92160-79af-4bf7-b770-263038e88900';
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const AR=id(1),AC=id(2),VR=id(3),VC=id(4),NEW=id(5),BAD=id(6),AS=id(10),EMP=id(11);
const eq=(a,b)=>{assert.deepEqual(a,b);checks++};
const scalar=async(sql,args=[]) => Object.values((await db.query(sql,args)).rows[0])[0];
async function as(role,user='') {
 await db.exec('RESET ROLE');
 await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claim.role',$2,false)",[user,role]);
 if(role!=='postgres')await db.exec('SET ROLE '+role);
}
async function denied(sql,args,pattern=/autorizad|asignacion|evento|permiso|encontrada|Chiapas|row.level|cuenta|Archivo|identity|no existe|inexistente/i) {
 let error;try{await db.query(sql,args)}catch(e){error=e}
 assert.ok(error,'La operación debió rechazarse');assert.match(error.message,pattern);checks++;
}
async function registrar(event,phone,type='vendedora',asesor=AS,photo=event+'/foto.png') {
 return scalar('select crear_registro_publico_v3($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,null)',[
  event,asesor,'PRUEBA LOCAL','FICTICIA','Chiapas',phone,type,'RUTA LOCAL',photo,
  type==='vendedora'?event+'/pago.png':null,type==='vendedora'?'CUENTA PRUEBA':null]);
}
try {
 await db.exec(`INSERT INTO auth.users(id) VALUES('${AR}'),('${AC}'),('${VR}'),('${VC}'),('${NEW}'),('${BAD}');
 INSERT INTO usuarios(id,nombre,nombre_usuario,rol) VALUES
 ('${AR}','PRUEBA ADMIN R','prueba.admin.r','administrador'),('${AC}','PRUEBA ADMIN C','prueba.admin.c','administrador'),
 ('${VR}','PRUEBA VALID R','prueba.valid.r','validador'),('${VC}','PRUEBA VALID C','prueba.valid.c','validador');
 INSERT INTO eventos(id,nombre,fecha_inicio,sede,estado,cuota_fija) VALUES
 ('${R}','PRUEBA RADEVS','2026-12-06','FICTICIA','activo',300),('${C}','PRUEBA CHIAPAS','2026-12-19','FICTICIA','borrador',300);
 INSERT INTO configuracion_cupo_evento(evento_id,cupo_maximo) VALUES('${R}',1500),('${C}',500);
 INSERT INTO usuarios_eventos(usuario_id,evento_id) VALUES('${AR}','${R}'),('${AC}','${C}'),('${VR}','${R}'),('${VC}','${C}');
 INSERT INTO asesores(id,nombre) VALUES('${AS}','PRUEBA ASESOR'),('${EMP}','EMPLEADO');`);
 const before=await db.query('select id,estado from eventos order by id');
 eq(await scalar("select has_table_privilege('service_role','public.usuarios_eventos','SELECT')"),false);
 const migration=fs.readdirSync('supabase/migrations').find(x=>x.endsWith('_aislar_eventos_radevs_chiapas.sql'));
 await db.exec(fs.readFileSync('supabase/migrations/'+migration,'utf8'));checks++;
 eq((await db.query('select id,estado from eventos order by id')).rows,before.rows);
 eq(await scalar("select has_table_privilege('service_role','public.usuarios_eventos','SELECT')"),true);
 eq(await scalar("select has_function_privilege('service_role','emitir_invitacion_admin_interna(uuid,uuid,boolean)','EXECUTE')"),false);
 await db.exec(fs.readFileSync('supabase/migrations/20261025031900_registro_prueba_independiente_chiapas.sql','utf8'));
 const oldTestHash=await scalar("select md5(pg_get_functiondef('crear_registro_prueba_admin_v2(uuid,uuid,text,text,text,text,text,text,text,text,text,integer)'::regprocedure))");
 await as('service_role');
 const trialArgs=[C,AS,'PRUEBA CHIAPAS','LOCAL','Chiapas','0000002040','vendedora','PRUEBA',C+'/foto.png',C+'/pago.png','CUENTA FICTICIA'];
 const trialSql='select crear_registro_prueba_admin_chiapas($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,null)';
 const trial=await scalar(trialSql,trialArgs);eq(trial.ok,true);eq(trial.es_prueba,true);
 eq(await scalar('select es_prueba from registros where id=$1',[trial.registro_id]),true);
 await denied(trialSql,[R,...trialArgs.slice(1)],/exclusiva de Chiapas/);
 await as('authenticated',AC);await denied(trialSql,trialArgs,/permission denied/);
 await as('anon');await denied(trialSql,trialArgs,/permission denied/);
 await as('postgres');
 eq(await scalar("select md5(pg_get_functiondef('crear_registro_prueba_admin_v2(uuid,uuid,text,text,text,text,text,text,text,text,text,integer)'::regprocedure))"),oldTestHash);
 await db.query('delete from pagos where registro_id=$1',[trial.registro_id]);
 const trialPerson=await scalar('select promotora_id from registros where id=$1',[trial.registro_id]);
 await db.query('delete from registros where id=$1',[trial.registro_id]);await db.query('delete from promotoras where id=$1',[trialPerson]);
 await as('service_role');
 const rr=await registrar(R,'5500000001'),rc=await registrar(C,'5500000001');
 eq(rr.ok,true);eq(rc.ok,true);assert.notEqual(rr.registro_id,rc.registro_id);checks++;
 eq((await registrar(R,'5500000001')).codigo,'DUPLICADO');
 await denied('select crear_perfil_evento_interno($1,$2,$3,$4,$5,$6)',[AR,C,NEW,'PRUEBA NUEVO','prueba.nuevo','acceso']);
 eq(await scalar('select count(*)::int from usuarios where id=$1',[NEW]),0);
 await db.query('select crear_perfil_evento_interno($1,$2,$3,$4,$5,$6)',[AR,R,NEW,'PRUEBA NUEVO','prueba.nuevo','acceso']);
 eq(await scalar('select count(*)::int from usuarios_eventos where usuario_id=$1 and evento_id=$2',[NEW,R]),1);
 await denied('select crear_perfil_evento_interno($1,$2,$3,$4,$5,$6)',[AR,R,BAD,'PRUEBA DUPLICADO','prueba.nuevo','acceso'],/duplicate key/i);
 eq(await scalar('select count(*)::int from usuarios where id=$1',[BAD]),0);
 eq((await registrar(R,'5500000002','promotora',EMP)).ok,true);
 await assert.rejects(registrar(C,'5500000003','promotora',EMP),/empleados/i);checks++;
 await assert.rejects(registrar(C,'5500000004','vendedora',AS,R+'/ajena.png'),/Archivo de otro evento/i);checks++;
 const pr=await scalar('select id from pagos where registro_id=$1',[rr.registro_id]);
 const pc=await scalar('select id from pagos where registro_id=$1',[rc.registro_id]);
 await as('authenticated',AR);
 eq(await scalar('select consultar_grupo_registro_admin($1)',[rr.registro_id]),'RUTA LOCAL');
 await denied('select consultar_grupo_registro_admin($1)',[rc.registro_id]);
 await as('authenticated',VR);
 await denied('select validar_pago_personal($1,$2,null)',[pc,'aprobar']);
 const aprobadoR=await scalar('select validar_pago_personal($1,$2,null)',[pr,'aprobar']);
 eq(aprobadoR.ok,true);assert.match(aprobadoR.invitacion.token_qr,/^[a-f0-9]{64}$/);checks++;
 await as('authenticated',VC);
 await denied('select validar_pago_personal_chiapas($1,$2,null)',[pr,'aprobar']);
 const aprobadoC=await scalar('select validar_pago_personal_chiapas($1,$2,null)',[pc,'aprobar']);
 eq(aprobadoC.ok,true);assert.match(aprobadoC.invitacion.token_qr,/^[a-f0-9]{64}$/);checks++;
 await as('service_role');
 const recuperado=await scalar('select recuperar_invitacion_admin_chiapas($1,$2,false)',[rc.registro_id,AC]);
 eq(recuperado.invitacion.token_qr,aprobadoC.invitacion.token_qr);
 await denied('select recuperar_invitacion_admin_chiapas($1,$2,false)',[rc.registro_id,AR]);
 const reemitido=await scalar('select recuperar_invitacion_admin_chiapas($1,$2,true)',[rc.registro_id,AC]);
 assert.notEqual(reemitido.invitacion.token_qr,aprobadoC.invitacion.token_qr);checks++;
 await as('authenticated',AR);
 eq((await scalar('select registrar_entrada_qr_evento($1,$2)',[reemitido.invitacion.token_qr,R])).ok,false);
 await as('authenticated',AC);
 eq((await scalar('select registrar_entrada_qr_evento($1,$2)',[aprobadoC.invitacion.token_qr,C])).estado,'no_autorizado');
 eq((await scalar('select registrar_entrada_qr_evento($1,$2)',[reemitido.invitacion.token_qr,C])).estado,'ingreso_registrado');
 eq((await scalar('select registrar_entrada_qr_evento($1,$2)',[reemitido.invitacion.token_qr,C])).estado,'ya_ingreso');
 await as('postgres');
 eq(await scalar('select count(*)::int from accesos'),1);
 eq(await scalar('select count(*)::int from registros where exento_pago'),0);
 // Failed transactions and encrypted-at-rest adapter: never substitute a plaintext mock.
 eq(await scalar('select count(*)::int from vault.fixture_secrets'),3);
 eq(await scalar("select bool_and(position(convert_to($1,'UTF8') in encrypted)=0) from vault.fixture_secrets",[reemitido.invitacion.token_qr]),true);
 const postData=await db.query('select id,estado from eventos order by id');eq(postData.rows,before.rows);
 // Both hard caps remain enforced even with an accidentally oversized configuration.
 for(const [event,cap] of [[R,1500],[C,500]]) {
  await db.exec('BEGIN');
  await db.query('update configuracion_cupo_evento set cupo_maximo=9999 where evento_id=$1',[event]);
  const occupied=await scalar("select count(*)::int from registros where evento_id=$1 and estado not in ('cancelado','rechazado')",[event]);
  await db.query(`WITH p AS (
    INSERT INTO promotoras(nombres,apellidos,telefono_whatsapp,estado_residencia,tipo_participante)
    SELECT 'PRUEBA CUPO','FICTICIA',lpad((6000000000+n)::text,10,'0'),'Chiapas','promotora' FROM generate_series(1,$2::int) n RETURNING id
   ) INSERT INTO registros(evento_id,promotora_id,asesor_id,folio,grupo_ruta)
     SELECT $1,id,$3,'PRUEBA-'||id::text,'RUTA LOCAL' FROM p`,[event,cap-occupied,AS]);
  eq(await scalar('select count(*)::int from registros where evento_id=$1',[event]),cap);
  await as('service_role');
  eq((await registrar(event,'5599999999')).codigo,'SIN_CUPO');
  await as('postgres');await db.exec('ROLLBACK');
 }
 // Full rollback must restore function definitions, grants, flags and policy set.
 await db.exec(fs.readFileSync('sql/security/rollback_eventos_completo.sql','utf8'));checks++;
 for(const fn of funciones)eq(await scalar('select md5(pg_get_functiondef(to_regprocedure($1)))',['public.'+fn.firma]),fn.hash);
 eq(await scalar("select has_table_privilege('service_role','public.usuarios_eventos','SELECT')"),false);
 eq(await scalar("select count(*)::int from pg_policies where schemaname='public'"),catalogo.policies.filter(p=>p.schemaname==='public').length);
 eq((await db.query('select id,estado from eventos order by id')).rows,before.rows);
 // Deliberate schema drift aborts before granting privileges or creating new RPCs.
 await db.exec(`CREATE OR REPLACE FUNCTION public.consultar_grupo_registro_admin(p_registro_id uuid) RETURNS text LANGUAGE sql AS $$ SELECT 'DRIFT'::text $$`);
 let driftError;try{await db.exec(fs.readFileSync('supabase/migrations/'+migration,'utf8'))}catch(e){driftError=e}
 assert.match(driftError?.message||'',/Definicion cambio/);checks++;
 await db.exec('ROLLBACK');
 eq(await scalar("select to_regprocedure('public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text)') is null"),true);
 eq(await scalar("select has_table_privilege('service_role','public.usuarios_eventos','SELECT')"),false);
 console.log(`${checks} comprobaciones aprobadas: migración y rollback íntegros, esquema catalogado, datos ficticios; PostgreSQL/pgcrypto reales, adaptadores locales Auth/Storage/Vault.`);
} catch(e) { console.error(e.message,e.where||'');process.exitCode=1; }
finally { await db.close(); }
