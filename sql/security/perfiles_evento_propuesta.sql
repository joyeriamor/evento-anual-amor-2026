BEGIN;
-- Required by the server-side assignment guard. Current production ACL lacks these.
GRANT SELECT, INSERT, UPDATE ON public.usuarios_eventos TO service_role;

CREATE OR REPLACE FUNCTION public.consultar_grupo_registro_admin(p_registro_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_grupo text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.usuarios u WHERE u.id=auth.uid() AND u.activo IS TRUE AND u.rol='administrador'
 ) THEN RAISE EXCEPTION 'No autorizado' USING ERRCODE='42501'; END IF;
 SELECT r.grupo_ruta INTO v_grupo FROM public.registros r
 WHERE r.id=p_registro_id AND EXISTS (
   SELECT 1 FROM public.usuarios_eventos ue
   WHERE ue.usuario_id=auth.uid() AND ue.evento_id=r.evento_id AND ue.activo IS TRUE
 );
 IF NOT FOUND THEN RAISE EXCEPTION 'Inscripción no encontrada' USING ERRCODE='42501'; END IF;
 RETURN v_grupo;
END;
$function$;
REVOKE ALL ON FUNCTION public.consultar_grupo_registro_admin(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.consultar_grupo_registro_admin(uuid) TO authenticated;

-- Auth account is created by the Edge first. Profile + assignment are one DB transaction.
-- On failure, the Edge removes only the newly-created Auth account; no orphan profile.
CREATE FUNCTION public.crear_perfil_evento_interno(
 p_admin_id uuid,p_evento_id uuid,p_usuario_id uuid,p_nombre text,p_nombre_usuario text,p_rol text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
   RAISE EXCEPTION 'Identidad incorrecta' USING ERRCODE='42501';
 END IF;
 IF p_evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid)
 OR NOT EXISTS (
   SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
   WHERE u.id=p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
     AND ue.evento_id=p_evento_id AND ue.activo IS TRUE
 ) THEN RAISE EXCEPTION 'Administrador no autorizado' USING ERRCODE='42501'; END IF;
 IF p_usuario_id IS NULL OR p_evento_id IS NULL OR p_rol IS NULL
 OR p_rol NOT IN ('administrador','validador','recepcion','acceso')
 OR p_nombre IS NULL OR char_length(btrim(p_nombre)) NOT BETWEEN 2 AND 120
 OR p_nombre_usuario IS NULL OR p_nombre_usuario !~ '^[a-z][a-z0-9._-]{2,31}$'
 THEN RAISE EXCEPTION 'Perfil inválido'; END IF;
 INSERT INTO public.usuarios(id,nombre,nombre_usuario,rol,activo)
 VALUES(p_usuario_id,btrim(p_nombre),p_nombre_usuario,p_rol,true);
 INSERT INTO public.usuarios_eventos(usuario_id,evento_id,activo)
 VALUES(p_usuario_id,p_evento_id,true);
 INSERT INTO public.auditoria(usuario_id,accion,entidad,entidad_id,detalles)
 VALUES(p_admin_id,'crear_usuario','usuarios',p_usuario_id,jsonb_build_object('evento_id',p_evento_id,'rol',p_rol));
END;
$function$;
REVOKE ALL ON FUNCTION public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text) TO service_role;
COMMIT;
