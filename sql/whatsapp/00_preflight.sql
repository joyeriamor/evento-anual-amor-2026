-- Read-only catalog guards. Abort on drift; never change original event permissions.
DO $$
DECLARE nombre text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid='public.whatsapp_envios_invitacion'::regclass AND relrowsecurity)
 OR NOT EXISTS(SELECT 1 FROM pg_class WHERE oid='public.whatsapp_consentimientos_invitacion'::regclass AND relrowsecurity)
 THEN RAISE EXCEPTION 'whatsapp_rls_no_verificado'; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles r CROSS JOIN pg_class c
 WHERE r.rolname IN ('anon','authenticated') AND c.oid IN ('public.whatsapp_envios_invitacion'::regclass,'public.whatsapp_consentimientos_invitacion'::regclass)
 AND (has_table_privilege(r.rolname,c.oid,'SELECT') OR has_table_privilege(r.rolname,c.oid,'INSERT') OR has_table_privilege(r.rolname,c.oid,'UPDATE')))
 THEN RAISE EXCEPTION 'whatsapp_permisos_publicos_cambiaron'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.whatsapp_envios_invitacion'::regclass
 AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (invitacion_id, plantilla)') THEN RAISE EXCEPTION 'whatsapp_unicidad_cambio'; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='whatsapp_envios_invitacion' AND column_name='automatizacion_version')
 THEN RAISE EXCEPTION 'whatsapp_paquete_ya_aplicado'; END IF;
 FOREACH nombre IN ARRAY ARRAY[
 'public.validar_pago_admin(uuid,text,text,uuid)','public.validar_pago_admin_chiapas(uuid,text,text,uuid)',
 'public.autorizar_cortesia_admin(uuid,uuid)','public.autorizar_cortesia_admin_chiapas(uuid,uuid)',
 'public.emitir_invitacion_admin_interna(uuid,uuid,boolean)','public.emitir_invitacion_chiapas_interna(uuid,uuid,boolean)',
 'public.crear_registro_publico_v4(uuid,uuid,text,text,text,text,text,text,text,text,text,integer,boolean)'] LOOP
 IF to_regprocedure(nombre) IS NULL OR has_function_privilege('anon',to_regprocedure(nombre),'EXECUTE')
 OR has_function_privilege('authenticated',to_regprocedure(nombre),'EXECUTE')
 THEN RAISE EXCEPTION 'whatsapp_funciones_base_no_verificadas'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM (VALUES
 ('emitir_invitacion_admin_interna','f3d31c075f6262b2ca4cbb9fbf5fc114'),
 ('validar_pago_admin','844e146fb4173713af1bc53e7a234ced'),
 ('validar_pago_admin_chiapas','5f602234bf5470a0c66099c3b2c4404c'),
 ('emitir_invitacion_chiapas_interna','b4bef4c8c2d645702e4150f18d9a17da'),
 ('autorizar_cortesia_admin_chiapas','b8cd70fb76f0cb5578275037d63f85cc'),
 ('autorizar_cortesia_admin','41bb2e8f423dab15d0c6ebd3f075df83'),
 ('crear_registro_publico_v4','56c9146e57f4cf7e44cd4a81fe8b7692')) esperado(nombre,hash)
 LEFT JOIN pg_proc p ON p.pronamespace='public'::regnamespace AND p.proname=esperado.nombre
 WHERE p.oid IS NULL OR md5(p.prosrc)<>esperado.hash) THEN RAISE EXCEPTION 'whatsapp_funciones_base_cambiaron'; END IF;
END $$;
