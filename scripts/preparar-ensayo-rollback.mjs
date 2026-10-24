// Builds a pg_temp-only rehearsal from the final migrated function bodies.
// Never connects to Supabase. The generated script must be reviewed before execution.
import fs from 'node:fs';
import { crearBaseCatalogo,catalogo } from '../tests/chiapas/base-catalogo.mjs';
const db=await crearBaseCatalogo();
try {
 const migration=fs.readdirSync('supabase/migrations').find(f=>f.endsWith('_aislar_eventos_radevs_chiapas.sql'));
 await db.exec(fs.readFileSync('supabase/migrations/'+migration,'utf8'));
 const names=['validar_pago_admin','validar_pago_admin_chiapas','validar_pago_personal','validar_pago_personal_chiapas',
  'autorizar_cortesia_admin','autorizar_cortesia_admin_chiapas','recuperar_invitacion_admin','recuperar_invitacion_admin_chiapas',
  'emitir_invitacion_admin_interna','emitir_invitacion_chiapas_interna','consultar_qr_acceso_evento','consultar_qr_acceso',
  'registrar_entrada_qr_evento','registrar_entrada_qr','bandejas_admin_paginadas','bandejas_admin_chiapas_paginadas',
  'crear_registro_publico_v3','crear_perfil_evento_interno','consultar_grupo_registro_admin',
  'evitar_acceso_duplicado','evitar_registro_duplicado','impedir_sobrecupo_evento','proteger_ultimo_administrador_activo'];
 const rows=(await db.query("select p.proname,pg_get_functiondef(p.oid) definition from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any($1::text[]) order by array_position($1::text[],p.proname::text)",[names])).rows;
 if(rows.length!==names.length)throw Error('Faltan funciones para el ensayo');
 const tables=['usuarios','usuarios_eventos','eventos','configuracion_cupo_evento','asesores','promotoras','registros','pagos','invitaciones','accesos','auditoria'];
 let sql=`-- ENSAYO REAL DE POSTGRESQL: SOLO pg_temp + datos ficticios + ROLLBACK.\n-- NO aplica la migración, modifica funciones public, usa filas reales, Auth ni Storage.\n-- Vault se sustituye por una tabla TEMPORAL; no se prueba Supabase Vault.\nBEGIN;\nSET LOCAL statement_timeout='30s';\nSET LOCAL lock_timeout='2s';\n`;
 for(const table of tables)sql+=`CREATE TEMP TABLE ${table} (LIKE public.${table} INCLUDING ALL) ON COMMIT DROP;\n`;
 sql+=`CREATE TEMP TABLE resultados_ensayo(caso text PRIMARY KEY,aprobado boolean NOT NULL) ON COMMIT DROP;
CREATE TEMP TABLE secretos_ensayo(id uuid PRIMARY KEY,decrypted_secret text NOT NULL) ON COMMIT DROP;
CREATE TEMP TABLE catalogo_antes_ensayo ON COMMIT DROP AS
 SELECT md5(string_agg(p.oid::text||pg_get_functiondef(p.oid)||coalesce(p.proacl::text,''),'|' ORDER BY p.oid)) huella
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f';
CREATE FUNCTION pg_temp.verificar_ensayo(p_caso text,p_ok boolean) RETURNS void LANGUAGE plpgsql AS $verify$
BEGIN
 IF p_ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO: %',p_caso; END IF;
 INSERT INTO pg_temp.resultados_ensayo VALUES(p_caso,true);
END;
$verify$;
CREATE FUNCTION pg_temp.crear_secreto_ensayo(text,text,text,uuid) RETURNS uuid LANGUAGE plpgsql AS $secret$
DECLARE v_id uuid:=gen_random_uuid(); BEGIN
 INSERT INTO pg_temp.secretos_ensayo VALUES(v_id,$1); RETURN v_id;
END;
$secret$;
`;
 for(const row of rows) {
  const rewritten=row.definition.replaceAll('public.','pg_temp.').replaceAll('vault.create_secret','pg_temp.crear_secreto_ensayo').replaceAll('vault.decrypted_secrets','pg_temp.secretos_ensayo')
   .replace(/SET search_path TO [^\n]+/g,"SET search_path TO ''")
   .replaceAll("'evento-anual-'","'ensayo-rollback-' || pg_catalog.pg_backend_pid()::text || '-'");
  if(/\b(?:public|vault)\./.test(rewritten))throw Error('Referencia fuera de pg_temp en '+row.proname);
  sql+=`\n-- Copia del cuerpo final: ${row.proname}\n${rewritten};\n`;
 }
 for(const trigger of catalogo.triggers) {
  if(tables.includes(trigger.tabla))sql+=trigger.definicion.replaceAll('public.','pg_temp.').replace(/EXECUTE FUNCTION (?!pg_temp\.)([a-z_]+)\(/,'EXECUTE FUNCTION pg_temp.$1(')+';\n';
 }
 sql+=fs.readFileSync('sql/security/ensayo_rollback_casos.sql','utf8');
 fs.writeFileSync('sql/security/ensayo_multievento_pg_temp_rollback.sql',sql);
 console.log('Ensayo pg_temp generado desde las funciones finales; sin conexión remota.');
}finally{await db.close();}
