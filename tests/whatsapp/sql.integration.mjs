// PGlite: real SQL against a synthetic catalog, NOT a production/Supabase integration test.
const {PGlite}=await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite();let checks=0;
const ok=(v)=>{assert(v);checks++;};
await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS 'SELECT NULL::uuid';
CREATE SCHEMA vault;CREATE TABLE vault.decrypted_secrets(id uuid PRIMARY KEY,decrypted_secret text);
CREATE TABLE public.usuarios(id uuid PRIMARY KEY,rol text,activo boolean);
CREATE TABLE public.usuarios_eventos(usuario_id uuid,evento_id uuid,activo boolean);
CREATE TABLE public.promotoras(id uuid PRIMARY KEY,nombres text,apellidos text,telefono_whatsapp text);
CREATE TABLE public.registros(id uuid PRIMARY KEY,evento_id uuid,promotora_id uuid,folio text,estado text,es_prueba boolean,exento_pago boolean);
CREATE TABLE public.pagos(id uuid PRIMARY KEY,registro_id uuid,estado text);
CREATE TABLE public.invitaciones(id uuid PRIMARY KEY,registro_id uuid,estado text,token_vault_id uuid,token_hash text,emitida_at timestamptz);
CREATE TABLE public.whatsapp_consentimientos_invitacion(registro_id uuid PRIMARY KEY REFERENCES registros(id),aceptado_at timestamptz NOT NULL,retirado_at timestamptz);
CREATE TABLE public.whatsapp_envios_invitacion(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),invitacion_id uuid NOT NULL REFERENCES invitaciones(id),
 plantilla text NOT NULL,idioma text NOT NULL,estado text NOT NULL CHECK(estado='pendiente_consentimiento'),
 consentimiento_confirmado_at timestamptz,meta_message_id text,intentos integer NOT NULL DEFAULT 0,
 ultimo_error_codigo text,ultimo_error_resumen text,siguiente_intento_at timestamptz,reservado_at timestamptz,
 aceptado_at timestamptz,entregado_at timestamptz,leido_at timestamptz,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now(),UNIQUE(invitacion_id,plantilla));
CREATE TABLE public.auditoria(usuario_id uuid,accion text,entidad text,entidad_id uuid,detalles jsonb);`);
for(const f of ['01_automatizacion_propuesta.sql','02_administracion_propuesta.sql','03_webhook_propuesta.sql'])await db.exec(await readFile(new URL('../../sql/whatsapp/'+f,import.meta.url),'utf8'));
const R='43e67bda-d19d-4c0e-a639-e85f2d62f294',C='3dc92160-79af-4bf7-b770-263038e88900';
const id=()=>crypto.randomUUID();
const admin=id();await db.query(`INSERT INTO usuarios VALUES($1,'administrador',true);`,[admin]);await db.query('INSERT INTO usuarios_eventos VALUES($1,$2,true)',[admin,C]);
async function crear({evento=C,consentimiento=true,prueba=false,estado='confirmado',cortesia=false,pago=true}={}){
 const r=id(),p=id(),i=id(),v=id();await db.query("INSERT INTO promotoras VALUES($1,'PERSONA','FICTICIA','9611234567')",[p]);
 await db.query('INSERT INTO registros VALUES($1,$2,$3,$4,$5,$6,$7)',[r,evento,p,'FICTICIO',estado,prueba,cortesia]);
 if(pago)await db.query("INSERT INTO pagos VALUES($1,$2,'validado')",[id(),r]);
 if(consentimiento)await db.query('INSERT INTO whatsapp_consentimientos_invitacion VALUES($1,now(),NULL)',[r]);
 await db.query("INSERT INTO vault.decrypted_secrets VALUES($1,'token-ficticio-vigente-123456')",[v]);
 await db.query("INSERT INTO invitaciones VALUES($1,$2,'activa',$3,encode(sha256(convert_to('token-ficticio-vigente-123456','UTF8')),'hex'),now())",[i,r,v]);return{r,i,v};}
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
await db.query("UPDATE whatsapp_envios_invitacion SET fase_automatizacion='incierto',inicio_meta_at=now() WHERE id=$1",[job.id]);
await assert.rejects(()=>db.query("SELECT whatsapp_admin_interno($1,$2,'reintentar',$3)",[admin,C,job.id]));checks++;
const entregable=(await db.query('SELECT id FROM whatsapp_envios_invitacion WHERE invitacion_id=$1',[cortesia.i])).rows[0].id;
await db.query("UPDATE whatsapp_envios_invitacion SET fase_automatizacion='aceptado',modo_automatizacion='real',meta_message_id='wamid.ficticio' WHERE id=$1",[entregable]);
ok((await db.query("SELECT whatsapp_confirmar_entrega_interno('wamid.otro','delivered',now()) b")).rows[0].b===false);
ok((await db.query("SELECT whatsapp_confirmar_entrega_interno('wamid.ficticio','read',now()) b")).rows[0].b===true);
await db.query("SELECT whatsapp_confirmar_entrega_interno('wamid.ficticio','delivered',now())");
ok((await db.query('SELECT fase_automatizacion f FROM whatsapp_envios_invitacion WHERE id=$1',[entregable])).rows[0].f==='leido');
const revocada=await crear({evento:R});await db.query("UPDATE invitaciones SET estado='revocada' WHERE id=$1",[revocada.i]);
ok((await db.query('SELECT whatsapp_contexto_interno($1) c',[revocada.i])).rows[0].c.codigo==='qr_no_vigente');
// A queue-specific insert error cannot roll back the original confirmation/QR operation.
await db.exec(`CREATE FUNCTION fallo_ficticio() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'fallo_ficticio'; END$$;
CREATE TRIGGER fallo_ficticio BEFORE INSERT ON whatsapp_envios_invitacion FOR EACH ROW EXECUTE FUNCTION fallo_ficticio();`);
const sinCola=await crear();ok(await cuenta(sinCola.i)===0);ok((await db.query('SELECT estado FROM registros WHERE id=$1',[sinCola.r])).rows[0].estado==='confirmado');
await db.exec('DROP TRIGGER fallo_ficticio ON whatsapp_envios_invitacion;DROP FUNCTION fallo_ficticio();');
await db.exec(await readFile(new URL('../../sql/whatsapp/rollback.sql',import.meta.url),'utf8'));ok((await db.query('SELECT count(*) n FROM registros')).rows[0].n>0);
await db.close();console.log(`${checks} comprobaciones SQL PGlite correctas; catálogo y datos ficticios, sin producción.`);
