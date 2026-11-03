-- SOLO LECTURA. Ejecutar únicamente por el mecanismo autorizado cuando vuelva a estar disponible.
BEGIN READ ONLY;
SELECT c.relname,c.relrowsecurity,c.relacl FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN ('whatsapp_envios_invitacion','whatsapp_consentimientos_invitacion');
SELECT table_name,column_name,data_type,is_nullable,column_default FROM information_schema.columns
 WHERE table_schema='public' AND table_name LIKE 'whatsapp_%' ORDER BY table_name,ordinal_position;
SELECT conrelid::regclass::text tabla,conname,pg_get_constraintdef(oid) definicion FROM pg_constraint
 WHERE conrelid IN ('public.whatsapp_envios_invitacion'::regclass,'public.whatsapp_consentimientos_invitacion'::regclass);
SELECT tablename,indexdef FROM pg_indexes WHERE schemaname='public' AND tablename LIKE 'whatsapp_%';
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
 WHERE schemaname='public' AND tablename LIKE 'whatsapp_%';
SELECT p.proname,p.proacl,pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND (p.proname LIKE '%whatsapp%' OR p.proname IN
 ('validar_pago_admin','validar_pago_admin_chiapas','autorizar_cortesia_admin','autorizar_cortesia_admin_chiapas',
 'emitir_invitacion_admin_interna','emitir_invitacion_chiapas_interna'));
SELECT event_object_table,trigger_name,action_statement FROM information_schema.triggers
 WHERE event_object_schema='public' AND event_object_table IN ('invitaciones','registros');
ROLLBACK;
