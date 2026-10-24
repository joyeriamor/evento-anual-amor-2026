// Generates only local SQL files. Never connects, applies, links or deploys.
import fs from 'node:fs';
import path from 'node:path';
const catalog=JSON.parse(fs.readFileSync('tests/fixtures/catalogo_rpc_20261024.json','utf8'));
const schema=JSON.parse(fs.readFileSync('tests/fixtures/catalogo_esquema_20261024.json','utf8'));
const sources=[
 'sql/security/radevs_administracion_propuesta.sql','sql/security/radevs_personal_propuesta.sql',
 'sql/chiapas/emitir_invitacion_chiapas_interna.sql','sql/chiapas/validar_pago_personal_chiapas_qr_integrado.sql',
 'sql/chiapas/funciones_administrativas_chiapas_propuesta.sql','sql/chiapas/bandejas_admin_chiapas_paginadas_propuesta.sql',
 'sql/security/radevs_bandejas_propuesta.sql','sql/security/qr_eventos_propuesta.sql','sql/chiapas/qr_legacy_compatibilidad.sql',
 'sql/security/perfiles_evento_propuesta.sql','sql/security/registro_multievento_propuesta.sql','sql/security/rls_storage_propuesta.sql',
];
const migration=fs.readdirSync('supabase/migrations').filter(f=>f.endsWith('_aislar_eventos_radevs_chiapas.sql'));
if(migration.length!==1)throw Error('Crear primero una única migración aislar_eventos_radevs_chiapas con la CLI.');
const literal=s=>"'"+s.replaceAll("'","''")+"'";
const preflight=catalog.map(f=>` IF to_regprocedure(${literal('public.'+f.firma)}) IS NULL OR md5(pg_get_functiondef(to_regprocedure(${literal('public.'+f.firma)}))) IS DISTINCT FROM ${literal(f.hash)} THEN RAISE EXCEPTION 'Definicion cambio: ${f.firma}'; END IF;`).join('\n');
const body=sources.map(file=>{
 const source=fs.readFileSync(file,'utf8').replace(/^BEGIN;\s*/m,'').replace(/COMMIT;\s*$/,'')
   .replace(/DO \$(verificacion|verificar_version|control|comprobacion)\$[\s\S]*?\$\1\$;/g,'');
 return `\n-- Source: ${file}\n${source}`;
}).join('\n');
const nuevos=['crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text)','bandejas_admin_chiapas_paginadas(text,integer,text,uuid)','recuperar_invitacion_admin_chiapas(uuid,uuid,boolean)','autorizar_cortesia_admin_chiapas(uuid,uuid)','validar_pago_admin_chiapas(uuid,text,text,uuid)','validar_pago_personal_chiapas(uuid,text,text)','emitir_invitacion_chiapas_interna(uuid,uuid,boolean)'];
const sinPreexistentes=nuevos.map(sig=>` IF to_regprocedure(${literal('public.'+sig)}) IS NOT NULL THEN RAISE EXCEPTION 'Funcion nueva ya existe: ${sig}'; END IF;`).join('\n');
const sql=`-- LOCAL PACKAGE ONLY. Apply exclusively after explicit production approval.\n-- No event states, registrations, payments or capacity configuration are changed.\nBEGIN;\nDO $catalog_preflight$\nBEGIN\n${preflight}\n${sinPreexistentes}\nEND;\n$catalog_preflight$;\n${body}\nCOMMIT;\n`;
fs.writeFileSync(path.join('supabase/migrations',migration[0]),sql);
const newFunctions=['crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text)','bandejas_admin_chiapas_paginadas(text,integer,text,uuid)','recuperar_invitacion_admin_chiapas(uuid,uuid,boolean)','autorizar_cortesia_admin_chiapas(uuid,uuid)','validar_pago_admin_chiapas(uuid,text,text,uuid)','validar_pago_personal_chiapas(uuid,text,text)','emitir_invitacion_chiapas_interna(uuid,uuid,boolean)'];
let rollback='-- Exact structural rollback to read-only catalog 2026-10-24. No user data is deleted.\nBEGIN;\n';
rollback+=fs.readFileSync('sql/security/rollback_rls_storage.sql','utf8').replace(/^BEGIN;\s*/m,'').replace(/COMMIT;\s*$/,'');
for(const fn of catalog) {
 if(fn.nombre==='rls_auto_enable')continue;
 const sig='public.'+fn.firma;rollback+='\n'+fn.definicion+';\n';
 rollback+=`REVOKE ALL ON FUNCTION ${sig} FROM PUBLIC,anon,authenticated,service_role;\n`;
 if(fn.acl===null)rollback+=`GRANT EXECUTE ON FUNCTION ${sig} TO PUBLIC;\n`;
 else for(const role of ['anon','authenticated','service_role']) if(fn.acl.includes(role+'=X/'))rollback+=`GRANT EXECUTE ON FUNCTION ${sig} TO ${role};\n`;
}
for(const sig of newFunctions)rollback+=`DROP FUNCTION IF EXISTS public.${sig};\n`;
for(const t of schema.tables)rollback+=`ALTER TABLE public."${t.nombre}" ${t.rls?'ENABLE':'DISABLE'} ROW LEVEL SECURITY;\nALTER TABLE public."${t.nombre}" ${t.force_rls?'FORCE':'NO FORCE'} ROW LEVEL SECURITY;\n`;
const acl=schema.tables.find(t=>t.nombre==='usuarios_eventos').acl.match(/service_role=([^/]*)\//)[1];
const permissions=Object.entries({a:'INSERT',r:'SELECT',w:'UPDATE',d:'DELETE',D:'TRUNCATE',x:'REFERENCES',t:'TRIGGER',m:'MAINTAIN'}).filter(([l])=>acl.includes(l)).map(([,p])=>p);
rollback+='REVOKE ALL ON public.usuarios_eventos FROM service_role;\n';
if(permissions.length)rollback+=`GRANT ${permissions.join(',')} ON public.usuarios_eventos TO service_role;\n`;
for(const b of schema.buckets)rollback+=`UPDATE storage.buckets SET public=${b.public?'true':'false'} WHERE id=${literal(b.id)};\n`;
rollback+='COMMIT;\n';fs.writeFileSync('sql/security/rollback_eventos_completo.sql',rollback);
console.log('Migración y rollback generados localmente; ninguna conexión a base de datos.');
