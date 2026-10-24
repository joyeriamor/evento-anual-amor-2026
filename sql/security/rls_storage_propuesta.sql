-- LOCAL ONLY. Review existing policies and schema dump; rehearse in disposable DB.
-- Restrictive policies intersect existing permissive policies; they grant no new access.
BEGIN;
ALTER TABLE public.registros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accesos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_eventos ENABLE ROW LEVEL SECURITY;
-- Anonymous users access only the dedicated public registration endpoints, never tables.
DO $policies$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('CREATE POLICY evento_privado_anon ON public.%I AS RESTRICTIVE FOR SELECT TO anon USING (false)',t);
  END LOOP;
END;
$policies$;
CREATE POLICY evento_perfil_propio ON public.usuarios AS RESTRICTIVE
FOR SELECT TO authenticated USING (id=(SELECT auth.uid()) AND activo IS TRUE);
CREATE POLICY evento_promotoras_lectura ON public.promotoras AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r WHERE r.promotora_id=promotoras.id)
);
-- All writes use the authorized Edge endpoints or checked SECURITY DEFINER RPCs.
DO $writes$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria'] LOOP
    EXECUTE format('CREATE POLICY evento_solo_backend_insert ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated,anon WITH CHECK(false)',t);
    EXECUTE format('CREATE POLICY evento_solo_backend_update ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated,anon USING(false) WITH CHECK(false)',t);
    EXECUTE format('CREATE POLICY evento_solo_backend_delete ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated,anon USING(false)',t);
  END LOOP;
END;
$writes$;
CREATE POLICY evento_auditoria_propia ON public.auditoria AS RESTRICTIVE
FOR SELECT TO authenticated USING (usuario_id=(SELECT auth.uid()));
CREATE POLICY evento_asignacion_propia ON public.usuarios_eventos AS RESTRICTIVE
FOR SELECT TO authenticated USING (usuario_id = (SELECT auth.uid()) AND activo IS TRUE);
CREATE POLICY evento_registros_lectura ON public.registros AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
    WHERE u.id=(SELECT auth.uid()) AND u.activo IS TRUE AND ue.activo IS TRUE
      AND ue.evento_id=registros.evento_id
      AND u.rol IN ('administrador','validador','recepcion','acceso'))
);
CREATE POLICY evento_pagos_lectura ON public.pagos AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
    JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE r.id=pagos.registro_id AND u.id=(SELECT auth.uid())
      AND u.activo IS TRUE AND ue.activo IS TRUE AND u.rol IN ('administrador','validador'))
);
CREATE POLICY evento_invitaciones_lectura ON public.invitaciones AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r WHERE r.id=invitaciones.registro_id)
);
CREATE POLICY evento_accesos_lectura ON public.accesos AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.invitaciones i WHERE i.id=accesos.invitacion_id)
);
CREATE POLICY evento_comprobantes_lectura ON storage.objects AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  bucket_id <> 'comprobantes-pago' OR EXISTS (
    SELECT 1 FROM public.pagos p JOIN public.registros r ON r.id=p.registro_id
      JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
      JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE p.comprobante_path=storage.objects.name AND u.id=(SELECT auth.uid())
      AND ue.activo IS TRUE AND u.activo IS TRUE AND u.rol IN ('administrador','validador')
  )
);
CREATE POLICY evento_fotos_lectura ON storage.objects AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  bucket_id <> 'fotos-promotoras' OR EXISTS (
    SELECT 1 FROM public.promotoras p JOIN public.registros r ON r.promotora_id=p.id
      JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
      JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE p.foto_path=storage.objects.name AND u.id=(SELECT auth.uid())
      AND ue.activo IS TRUE AND u.activo IS TRUE
      AND u.rol IN ('administrador','validador','recepcion','acceso')
  )
);
CREATE POLICY evento_archivos_anon ON storage.objects AS RESTRICTIVE
FOR SELECT TO anon USING (bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_insert ON storage.objects AS RESTRICTIVE
FOR INSERT TO authenticated,anon WITH CHECK(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_update ON storage.objects AS RESTRICTIVE
FOR UPDATE TO authenticated,anon
USING(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'))
WITH CHECK(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_delete ON storage.objects AS RESTRICTIVE
FOR DELETE TO authenticated,anon USING(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
-- Public bucket URLs bypass RLS. Private status is a prerequisite, not a substitute.
UPDATE storage.buckets SET public=false WHERE id IN ('comprobantes-pago','fotos-promotoras');
COMMIT;
