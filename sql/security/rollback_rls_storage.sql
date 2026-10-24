-- LOCAL ONLY. Roll back only the policies introduced by rls_storage_propuesta.sql.
-- Restore prior RLS flags, bucket visibility and function definitions/ACL from
-- the approved pre-deployment snapshot; never guess a production prior state.
BEGIN;
DROP POLICY IF EXISTS evento_asignacion_propia ON public.usuarios_eventos;
DROP POLICY IF EXISTS evento_registros_lectura ON public.registros;
DROP POLICY IF EXISTS evento_pagos_lectura ON public.pagos;
DROP POLICY IF EXISTS evento_invitaciones_lectura ON public.invitaciones;
DROP POLICY IF EXISTS evento_accesos_lectura ON public.accesos;
DROP POLICY IF EXISTS evento_comprobantes_lectura ON storage.objects;
DROP POLICY IF EXISTS evento_fotos_lectura ON storage.objects;
DROP POLICY IF EXISTS evento_archivos_anon ON storage.objects;
DROP POLICY IF EXISTS evento_auditoria_propia ON public.auditoria;
DROP POLICY IF EXISTS evento_archivos_insert ON storage.objects;
DROP POLICY IF EXISTS evento_archivos_update ON storage.objects;
DROP POLICY IF EXISTS evento_archivos_delete ON storage.objects;
DROP POLICY IF EXISTS evento_perfil_propio ON public.usuarios;
DROP POLICY IF EXISTS evento_promotoras_lectura ON public.promotoras;
DO $policies$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS evento_privado_anon ON public.%I',t);
    EXECUTE format('DROP POLICY IF EXISTS evento_solo_backend_insert ON public.%I',t);
    EXECUTE format('DROP POLICY IF EXISTS evento_solo_backend_update ON public.%I',t);
    EXECUTE format('DROP POLICY IF EXISTS evento_solo_backend_delete ON public.%I',t);
  END LOOP;
END;
$policies$;
COMMIT;
