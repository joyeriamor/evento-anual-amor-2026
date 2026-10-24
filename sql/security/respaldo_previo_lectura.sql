-- Read-only. Save complete result outside the database before approved deployment.
SELECT p.oid::regprocedure AS firma, pg_get_functiondef(p.oid) AS definicion,
       pg_get_userbyid(p.proowner) AS propietario, p.proacl AS permisos
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND (
  p.proname IN ('validar_pago_admin','autorizar_cortesia_admin','recuperar_invitacion_admin',
  'emitir_invitacion_admin_interna','bandejas_admin_paginadas','validar_pago_personal',
  'consultar_qr_acceso','registrar_entrada_qr','consultar_qr_acceso_evento','registrar_entrada_qr_evento')
  OR p.proname LIKE '%chiapas%');
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies WHERE schemaname IN ('public','storage');

SELECT n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','storage') AND c.relkind='r';
SELECT id,public FROM storage.buckets WHERE id IN ('comprobantes-pago','fotos-promotoras');

-- Catalog of ALL callable functions, including unversioned SECURITY DEFINER APIs.
SELECT p.oid::regprocedure firma,p.prosecdef,p.proacl,pg_get_functiondef(p.oid) definicion
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f';
