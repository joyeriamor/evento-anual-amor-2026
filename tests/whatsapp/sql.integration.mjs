// PGlite: real SQL against a synthetic catalog, NOT a production/Supabase integration test.
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
let db,pgClient,Client;
if(process.env.FIESTA_WHATSAPP_PG_URL){
 const u=new URL(process.env.FIESTA_WHATSAPP_PG_URL);
 if(u.hostname!=='127.0.0.1'||!u.pathname.startsWith('/fiesta_whatsapp_'))throw Error('Solo base local ficticia');
 const pg=await import(process.env.PG_MODULE||'pg');Client=pg.Client??pg.default.Client;
 pgClient=new Client({connectionString:u.toString()});await pgClient.connect();
 db={exec:sql=>pgClient.query(sql),query:(sql,args)=>pgClient.query(sql,args),close:()=>pgClient.end()};
}else{const{PGlite}=await import(process.env.PGLITE_MODULE||'@electric-sql/pglite');db=new PGlite();}
let checks=0;
process.on('uncaughtException',e=>{console.error('FALLO SQL LOCAL:',e.code??'',e.message);process.exit(1)});
const ok=(v)=>{assert(v);checks++;};
await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('test.uid',true),'')::uuid$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql AS $$SELECT current_setting('test.role',true)$$;
CREATE SCHEMA vault;CREATE TABLE vault.decrypted_secrets(id uuid PRIMARY KEY,decrypted_secret text);
CREATE TABLE public.usuarios(id uuid PRIMARY KEY,rol text,activo boolean);
CREATE TABLE public.usuarios_eventos(usuario_id uuid,evento_id uuid,activo boolean);
CREATE TABLE public.eventos(id uuid PRIMARY KEY);
CREATE TABLE public.asesores(id uuid PRIMARY KEY,nombre text,activo boolean);
CREATE TABLE public.configuracion_cupo_evento(evento_id uuid,cupo_maximo integer);
CREATE TABLE public.promotoras(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),nombres text,apellidos text,telefono_whatsapp text,estado_residencia text,tipo_participante text,foto_path text);
CREATE TABLE public.registros(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),evento_id uuid,promotora_id uuid,folio text,estado text,es_prueba boolean,exento_pago boolean,asesor_id uuid,grupo_ruta text,aviso_privacidad_aceptado_at timestamptz);
CREATE TABLE public.pagos(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),registro_id uuid,estado text,importe numeric,comprobante_path text,cuenta_destino text,validado_por uuid,validado_at timestamptz);
CREATE TABLE public.invitaciones(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),registro_id uuid,estado text,token_vault_id uuid,token_hash text,emitida_at timestamptz,emitida_por uuid,revocada_at timestamptz);
CREATE TABLE public.whatsapp_consentimientos_invitacion(registro_id uuid PRIMARY KEY REFERENCES registros(id) ON DELETE RESTRICT,
 aceptado_at timestamptz NOT NULL,retirado_at timestamptz,origen text NOT NULL CHECK(origen IN ('formulario_registro','confirmacion_directa','mensaje_entrante_whatsapp')),
 aviso_version text NOT NULL CHECK(length(btrim(aviso_version)) BETWEEN 3 AND 80),evidencia_referencia text CHECK(length(evidencia_referencia)<=250),
 actualizado_at timestamptz DEFAULT now(),registrado_por uuid,CHECK(retirado_at IS NULL OR retirado_at>=aceptado_at));
CREATE TABLE public.whatsapp_envios_invitacion(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),invitacion_id uuid NOT NULL REFERENCES invitaciones(id),
 plantilla text NOT NULL,idioma text NOT NULL,estado text NOT NULL CONSTRAINT whatsapp_envios_estado_chk CHECK(estado IN ('pendiente_consentimiento','listo','enviando','aceptado_meta','entregado','leido','fallido','cancelado','revision')),
 consentimiento_confirmado_at timestamptz,meta_message_id text,intentos integer NOT NULL DEFAULT 0 CHECK(intentos>=0),
 ultimo_error_codigo text,ultimo_error_resumen text,siguiente_intento_at timestamptz,reservado_at timestamptz,
 aceptado_at timestamptz,entregado_at timestamptz,leido_at timestamptz,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now(),UNIQUE(invitacion_id,plantilla),CHECK(estado NOT IN ('listo','enviando','aceptado_meta','entregado','leido') OR consentimiento_confirmado_at IS NOT NULL));
CREATE UNIQUE INDEX whatsapp_envios_meta_message_id_uq ON public.whatsapp_envios_invitacion(meta_message_id) WHERE meta_message_id IS NOT NULL;
ALTER TABLE public.whatsapp_envios_invitacion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_consentimientos_invitacion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.whatsapp_envios_invitacion,public.whatsapp_consentimientos_invitacion FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE public.auditoria(usuario_id uuid,accion text,entidad text,entidad_id uuid,detalles jsonb);`);
await db.exec(`CREATE FUNCTION vault.create_secret(valor text,nombre text,descripcion text,clave uuid) RETURNS uuid LANGUAGE plpgsql AS $$DECLARE i uuid:=gen_random_uuid();BEGIN INSERT INTO vault.decrypted_secrets VALUES(i,valor);RETURN i;END$$;`);
for(const f of ['registro_publico_v4_publicado.sql','confirmaciones_publicadas.sql'])await db.exec((await readFile(new URL('../../sql/whatsapp/referencias/'+f,import.meta.url),'utf8')).replace(/\r\n/g,'\n'));
await db.exec(`REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;`);
await db.exec(await readFile(new URL('../../sql/whatsapp/00_preflight.sql',import.meta.url),'utf8'));
if(process.env.FIESTA_WHATSAPP_MIGRACION)await db.exec(await readFile(process.env.FIESTA_WHATSAPP_MIGRACION,'utf8'));
else for(const f of ['01_automatizacion_propuesta.sql','02_administracion_propuesta.sql','03_webhook_propuesta.sql','04_consulta_privada_propuesta.sql','05_medios_privados_propuesta.sql'])await db.exec(await readFile(new URL('../../sql/whatsapp/'+f,import.meta.url),'utf8'));
const R='43e67bda-d19d-4c0e-a639-e85f2d62f294',C='3dc92160-79af-4bf7-b770-263038e88900';
const id=()=>crypto.randomUUID();
const admin=id();await db.query(`INSERT INTO usuarios VALUES($1,'administrador',true);`,[admin]);await db.query('INSERT INTO usuarios_eventos VALUES($1,$2,true)',[admin,C]);
async function crear({evento=C,consentimiento=true,prueba=false,estado='confirmado',cortesia=false,pago=true}={}){
 const r=id(),p=id(),i=id(),v=id();await db.query("INSERT INTO promotoras(id,nombres,apellidos,telefono_whatsapp) VALUES($1,'PERSONA','FICTICIA','9611234567')",[p]);
 await db.query('INSERT INTO registros(id,evento_id,promotora_id,folio,estado,es_prueba,exento_pago) VALUES($1,$2,$3,$4,$5,$6,$7)',[r,evento,p,'FICTICIO',estado,prueba,cortesia]);
 if(pago)await db.query("INSERT INTO pagos(id,registro_id,estado) VALUES($1,$2,'validado')",[id(),r]);
 if(consentimiento)await db.query("INSERT INTO whatsapp_consentimientos_invitacion(registro_id,aceptado_at,retirado_at,origen,aviso_version) VALUES($1,now(),NULL,'formulario_registro','whatsapp_invitacion_v1')",[r]);
 await db.query("INSERT INTO vault.decrypted_secrets VALUES($1,'token-ficticio-vigente-123456')",[v]);
 await db.query("INSERT INTO invitaciones(id,registro_id,estado,token_vault_id,token_hash,emitida_at) VALUES($1,$2,'activa',$3,encode(sha256(convert_to('token-ficticio-vigente-123456','UTF8')),'hex'),now())",[i,r,v]);return{r,i,v};}
async function cuenta(i){return Number((await db.query('SELECT count(*) n FROM whatsapp_envios_invitacion WHERE invitacion_id=$1',[i])).rows[0].n);}
const pagado=await crear();ok(await cuenta(pagado.i)===1);
const cortesia=await crear({cortesia:true,pago:false});ok(await cuenta(cortesia.i)===1);
for(const opt of [{consentimiento:false},{prueba:true},{estado:'rechazado'},{pago:false}]){const f=await crear(opt);ok(await cuenta(f.i)===0);}
await db.query('SELECT whatsapp_encolar_interno($1)',[pagado.i]);ok(await cuenta(pagado.i)===1);
let context=(await db.query('SELECT whatsapp_contexto_interno($1) c',[pagado.i])).rows[0].c;ok(context.token_qr==='token-ficticio-vigente-123456');
await db.query("UPDATE vault.decrypted_secrets SET decrypted_secret='alterado' WHERE id=$1",[pagado.v]);context=(await db.query('SELECT whatsapp_contexto_interno($1) c',[pagado.i])).rows[0].c;ok(context.codigo==='qr_no_recuperable');
await db.query("UPDATE vault.decrypted_secrets SET decrypted_secret='token-ficticio-vigente-123456' WHERE id=$1",[pagado.v]);
const job=(await db.query("SELECT whatsapp_reservar_interno('simulacion') j")).rows[0].j;ok(!!job.reserva_id);
const wrong=(await db.query("SELECT whatsapp_finalizar_interno($1,$2,'fallido','preparacion_fallida') b",[job.id,id()])).rows[0].b;ok(wrong===false);
await db.query("SELECT whatsapp_finalizar_interno($1,$2,'fallido','preparacion_fallida')",[job.id,job.reserva_id]);
ok((await db.query("SELECT whatsapp_admin_interno($1,$2,'reintentar',$3) a",[admin,C,job.id])).rows[0].a.ok===true);
await assert.rejects(()=>db.query("SELECT whatsapp_admin_interno($1,$2,'listar')",[admin,R]));checks++;
const sinPermiso=(await db.query("SELECT has_function_privilege('authenticated','public.whatsapp_contexto_interno(uuid)','EXECUTE') permiso")).rows[0].permiso;ok(sinPermiso===false);
await db.query('UPDATE whatsapp_consentimientos_invitacion SET retirado_at=now() WHERE registro_id=$1',[pagado.r]);context=(await db.query('SELECT whatsapp_contexto_interno($1) c',[pagado.i])).rows[0].c;ok(context.codigo==='sin_consentimiento');
// Event isolation in both directions and inactive assignments/profiles.
const rAdmin=id();await db.query("INSERT INTO usuarios VALUES($1,'administrador',true)",[rAdmin]);
await db.query('INSERT INTO usuarios_eventos VALUES($1,$2,true)',[rAdmin,R]);
await assert.rejects(()=>db.query("SELECT whatsapp_admin_interno($1,$2,'listar')",[rAdmin,C]));checks++;
ok((await db.query("SELECT whatsapp_admin_interno($1,$2,'listar') x",[rAdmin,R])).rows[0].x.ok);
await db.query('UPDATE usuarios_eventos SET activo=false WHERE usuario_id=$1',[admin]);
await assert.rejects(()=>db.query("SELECT whatsapp_admin_interno($1,$2,'listar')",[admin,C]));checks++;
await db.query('UPDATE usuarios_eventos SET activo=true WHERE usuario_id=$1',[admin]);
await db.query('UPDATE usuarios SET activo=false WHERE id=$1',[admin]);
await assert.rejects(()=>db.query("SELECT whatsapp_admin_interno($1,$2,'listar')",[admin,C]));checks++;
await db.query('UPDATE usuarios SET activo=true WHERE id=$1',[admin]);
// A message with an uncertain result can never be manually requeued.
await db.query("UPDATE whatsapp_envios_invitacion SET estado='revision',inicio_meta_at=now() WHERE id=$1",[job.id]);
await assert.rejects(()=>db.query("SELECT whatsapp_admin_interno($1,$2,'reintentar',$3)",[admin,C,job.id]));checks++;
const entregable=(await db.query('SELECT id FROM whatsapp_envios_invitacion WHERE invitacion_id=$1',[cortesia.i])).rows[0].id;
await db.query("UPDATE whatsapp_envios_invitacion SET estado='aceptado_meta',modo_automatizacion='real',meta_message_id='wamid.ficticio' WHERE id=$1",[entregable]);
ok((await db.query("SELECT whatsapp_confirmar_entrega_interno('wamid.otro','delivered',now()) b")).rows[0].b===false);
ok((await db.query("SELECT whatsapp_confirmar_entrega_interno('wamid.ficticio','read',now()) b")).rows[0].b===true);
await db.query("SELECT whatsapp_confirmar_entrega_interno('wamid.ficticio','delivered',now())");
ok((await db.query('SELECT estado f FROM whatsapp_envios_invitacion WHERE id=$1',[entregable])).rows[0].f==='leido');
const revocada=await crear({evento:R});await db.query("UPDATE invitaciones SET estado='revocada' WHERE id=$1",[revocada.i]);
ok((await db.query('SELECT whatsapp_contexto_interno($1) c',[revocada.i])).rows[0].c.codigo==='qr_no_vigente');
// A queue-specific insert error cannot roll back the original confirmation/QR operation.
await db.exec(`CREATE FUNCTION fallo_ficticio() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'fallo_ficticio'; END$$;
CREATE TRIGGER fallo_ficticio BEFORE INSERT ON whatsapp_envios_invitacion FOR EACH ROW EXECUTE FUNCTION fallo_ficticio();`);
const sinCola=await crear();ok(await cuenta(sinCola.i)===0);ok((await db.query('SELECT estado FROM registros WHERE id=$1',[sinCola.r])).rows[0].estado==='confirmado');
await db.exec('DROP TRIGGER fallo_ficticio ON whatsapp_envios_invitacion;DROP FUNCTION fallo_ficticio();');
// Actual audited private-table ACLs: service can use constrained functions, not direct reads.
await db.exec('SET ROLE service_role');
await assert.rejects(()=>db.query('SELECT * FROM whatsapp_envios_invitacion'));checks++;
const metadata=await db.query("SELECT whatsapp_preparar_admin_interno($1,$2,false) j",[cortesia.r,admin]);
ok(metadata.rows[0].j.ok===true);ok(!JSON.stringify(metadata.rows[0].j).includes('token_qr'));
const qrLeido=await db.query('SELECT whatsapp_qr_admin_interno($1,$2) j',[cortesia.i,admin]);
ok(qrLeido.rows[0].j.token_qr==='token-ficticio-vigente-123456');
await db.exec('RESET ROLE');
const antesInv=Number((await db.query('SELECT count(*) n FROM invitaciones')).rows[0].n);
await db.query("UPDATE invitaciones SET estado='revocada' WHERE id=$1",[cortesia.i]);
await assert.rejects(()=>db.query('SELECT whatsapp_qr_admin_interno($1,$2)',[cortesia.i,admin]));checks++;
ok(Number((await db.query('SELECT count(*) n FROM invitaciones')).rows[0].n)===antesInv);
// Signed status may arrive before the sender persists the message id.
const temprano=await crear();const tempranoJob=(await db.query('SELECT id FROM whatsapp_envios_invitacion WHERE invitacion_id=$1',[temprano.i])).rows[0].id;
const reservaTemprana=id();await db.query("UPDATE whatsapp_envios_invitacion SET estado='enviando',reserva_id=$2,modo_automatizacion='real' WHERE id=$1",[tempranoJob,reservaTemprana]);
await db.query("SELECT whatsapp_confirmar_entrega_interno('wamid.temprano','delivered',now())");
await db.query("SELECT whatsapp_finalizar_interno($1,$2,'aceptado',NULL,'wamid.temprano')",[tempranoJob,reservaTemprana]);
ok((await db.query('SELECT estado FROM whatsapp_envios_invitacion WHERE id=$1',[tempranoJob])).rows[0].estado==='entregado');
// Media references persist before dispatch and are cleared only after confirmed private deletion.
const mediaFixture=await crear();const mediaJob=(await db.query('SELECT id FROM whatsapp_envios_invitacion WHERE invitacion_id=$1',[mediaFixture.i])).rows[0].id;
const mr=id();await db.query("UPDATE whatsapp_envios_invitacion SET estado='enviando',reserva_id=$2,modo_automatizacion='real' WHERE id=$1",[mediaJob,mr]);
ok((await db.query("SELECT whatsapp_guardar_medio_interno($1,$2,'123456') b",[mediaJob,mr])).rows[0].b);
await db.query("SELECT whatsapp_finalizar_interno($1,$2,'fallido','preparacion_fallida')",[mediaJob,mr]);
await assert.rejects(()=>db.query("SELECT whatsapp_admin_interno($1,$2,'reintentar',$3)",[admin,C,mediaJob]));checks++;
ok((await db.query("SELECT whatsapp_marcar_medio_eliminado_interno($1,$2,'123456') b",[mediaJob,mr])).rows[0].b);
ok((await db.query("SELECT whatsapp_admin_interno($1,$2,'reintentar',$3) j",[admin,C,mediaJob])).rows[0].j.ok);
// Cleanup of confirmed-delivered media after seven days; accepted/uncertain stays private for review.
await db.query("UPDATE whatsapp_envios_invitacion SET estado='entregado',media_eliminado_at=NULL,media_subido_at=now()-interval '8 days' WHERE id=$1",[mediaJob]);
const limpio=(await db.query('SELECT whatsapp_reservar_limpieza_interno() j')).rows[0].j;
ok(limpio.id===mediaJob);ok(limpio.media_id==='123456');
ok((await db.query('SELECT whatsapp_finalizar_limpieza_interno($1,$2,$3) b',[mediaJob,id(),limpio.media_id])).rows[0].b===false);
ok((await db.query('SELECT whatsapp_finalizar_limpieza_interno($1,$2,$3) b',[mediaJob,limpio.reserva_id,limpio.media_id])).rows[0].b);
for(const estado of ['aceptado_meta','revision']){
 await db.query('UPDATE whatsapp_envios_invitacion SET estado=$2,media_eliminado_at=NULL,media_limpieza_reservada_at=NULL WHERE id=$1',[mediaJob,estado]);
 ok((await db.query('SELECT whatsapp_reservar_limpieza_interno() j')).rows[0].j===null);
}
// A SQL identity claim cannot impersonate a different admin.
await db.query("SELECT set_config('test.uid',$1,false)",[id()]);
await assert.rejects(()=>db.query('SELECT whatsapp_preparar_admin_interno($1,$2,false)',[temprano.r,admin]));checks++;
await db.query("SELECT set_config('test.uid','',false)");
// A provider failure is distinct from acceptance and never enables blind resend.
const providerFallo=await crear();const pfJob=(await db.query('SELECT id FROM whatsapp_envios_invitacion WHERE invitacion_id=$1',[providerFallo.i])).rows[0].id;const pfReserva=id();
await db.query("UPDATE whatsapp_envios_invitacion SET estado='enviando',reserva_id=$2,modo_automatizacion='real',inicio_meta_at=now() WHERE id=$1",[pfJob,pfReserva]);
await db.query("SELECT whatsapp_confirmar_entrega_interno('wamid.fallo','failed',now())");
await db.query("SELECT whatsapp_finalizar_interno($1,$2,'aceptado',NULL,'wamid.fallo')",[pfJob,pfReserva]);
const pf=(await db.query('SELECT estado,entregado_at,ultimo_error_codigo FROM whatsapp_envios_invitacion WHERE id=$1',[pfJob])).rows[0];
ok(pf.estado==='fallido');ok(pf.entregado_at===null);ok(pf.ultimo_error_codigo==='meta_entrega_fallida');
await assert.rejects(()=>db.query("SELECT whatsapp_admin_interno($1,$2,'reintentar',$3)",[admin,C,pfJob]));checks++;
// The existing v4 registration operation records explicit consent atomically for both events.

await db.exec("REVOKE ALL ON FUNCTION public.crear_registro_publico_v4(uuid,uuid,text,text,text,text,text,text,text,text,text,integer,boolean) FROM PUBLIC,anon,authenticated");
await db.query("SELECT set_config('test.role','service_role',false)");
const asesor=id();await db.query("INSERT INTO asesores VALUES($1,'LUIS',true)",[asesor]);
let telefonoSeq=1000000;
for(const evento of [R,C]){
 await db.query('INSERT INTO eventos VALUES($1)',[evento]);
 for(const acepta of [false,true])for(const tipo of ['vendedora','promotora']){
  const telefono='961'+String(++telefonoSeq);
  const resultado=(await db.query("SELECT crear_registro_publico_v4($1,$2,'FICTICIA','REGISTRO','Chiapas',$3,$7,'RUTA FICTICIA',$4,$5,$8,NULL,$6) j",[evento,asesor,telefono,evento+'/foto-ficticia.png',tipo==='vendedora'?evento+'/pago-ficticio.png':null,acepta,tipo,tipo==='vendedora'?'cuenta-ficticia':null])).rows[0].j;
  ok(resultado.ok===true);ok(resultado.estado==='pendiente');
  ok(Number((await db.query('SELECT count(*) n FROM whatsapp_consentimientos_invitacion WHERE registro_id=$1',[resultado.registro_id])).rows[0].n)===(acepta?1:0));
  ok(Number((await db.query('SELECT count(*) n FROM invitaciones WHERE registro_id=$1',[resultado.registro_id])).rows[0].n)===0);
  const actor=evento===R?rAdmin:admin;
  if(tipo==='vendedora'){
   const pago=(await db.query('SELECT id FROM pagos WHERE registro_id=$1',[resultado.registro_id])).rows[0].id;
   await db.query(`SELECT ${evento===R?'validar_pago_admin':'validar_pago_admin_chiapas'}($1,'aprobar',NULL,$2)`,[pago,actor]);
  }else await db.query(`SELECT ${evento===R?'autorizar_cortesia_admin':'autorizar_cortesia_admin_chiapas'}($1,$2)`,[resultado.registro_id,actor]);
  ok((await db.query('SELECT estado FROM registros WHERE id=$1',[resultado.registro_id])).rows[0].estado==='confirmado');
  const invitacion=(await db.query('SELECT id FROM invitaciones WHERE registro_id=$1',[resultado.registro_id])).rows[0].id;
  ok(await cuenta(invitacion)===(acepta?1:0));

 }
}
if(pgClient){
 const a=new Client({connectionString:process.env.FIESTA_WHATSAPP_PG_URL}),b=new Client({connectionString:process.env.FIESTA_WHATSAPP_PG_URL});
 await Promise.all([a.connect(),b.connect()]);
 try{
  await Promise.all([a.query('SET statement_timeout=3000'),b.query('SET statement_timeout=3000')]);
  const paralelo=await crear({consentimiento:false});
  await db.query("INSERT INTO whatsapp_consentimientos_invitacion(registro_id,aceptado_at,origen,aviso_version) VALUES($1,now(),'formulario_registro','whatsapp_invitacion_v1')",[paralelo.r]);
  const r=await Promise.all([a,b].map(c=>c.query('SELECT whatsapp_encolar_interno($1) b',[paralelo.i])));
  ok(r.filter(x=>x.rows[0].b).length===1);ok(await cuenta(paralelo.i)===1);
  await db.query("UPDATE whatsapp_envios_invitacion SET estado='cancelado' WHERE invitacion_id<>$1",[paralelo.i]);
  await a.query('BEGIN');const reservado=(await a.query("SELECT whatsapp_reservar_interno('simulacion') j")).rows[0].j;
  ok(!!reservado?.reserva_id);ok((await b.query("SELECT whatsapp_reservar_interno('simulacion') j")).rows[0].j===null);
  await a.query('COMMIT');
  await db.query("UPDATE whatsapp_envios_invitacion SET reservado_at=now()-interval '11 minutes' WHERE id=$1",[reservado.id]);
  await b.query("SELECT whatsapp_reservar_interno('simulacion')");
  ok((await a.query("SELECT whatsapp_finalizar_interno($1,$2,'simulado') b",[reservado.id,reservado.reserva_id])).rows[0].b===false);
  // Lock-order regression: a confirmation holds registro before touching the invitation.
  await a.query('BEGIN');await a.query('SELECT id FROM registros WHERE id=$1 FOR UPDATE',[paralelo.r]);
  const pid=(await b.query('SELECT pg_backend_pid() p')).rows[0].p;
  const esperando=b.query('SELECT whatsapp_contexto_interno($1) j',[paralelo.i]);
  let bloqueado=false;for(let n=0;n<80;n++){
   const q=(await db.query('SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1',[pid])).rows[0];
   if(q?.wait_event_type==='Lock'){bloqueado=true;break;}await new Promise(r=>setTimeout(r,25));
  }ok(bloqueado);
  await a.query('SELECT id FROM invitaciones WHERE id=$1 FOR UPDATE',[paralelo.i]);await a.query('COMMIT');
  ok((await esperando).rows[0].j.elegible===true);
 }finally{await a.query('ROLLBACK').catch(()=>{});await Promise.all([a.end(),b.end()]);}
}
if(process.env.FIESTA_WHATSAPP_ENSAYO_SQL){const {probarEnsayo}=await import('./ensayo-plataforma.sql.test.mjs');await probarEnsayo({db,admin,rAdmin,C,R,ok});}
await db.exec(await readFile(new URL('../../sql/whatsapp/rollback.sql',import.meta.url),'utf8'));ok((await db.query('SELECT count(*) n FROM registros')).rows[0].n>0);
await db.close();console.log(`${checks} comprobaciones SQL ${pgClient?"PostgreSQL nativo concurrente":"PGlite"} correctas; catálogo y datos ficticios, sin producción.`);
