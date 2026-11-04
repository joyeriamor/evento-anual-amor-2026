BEGIN;
CREATE FUNCTION public.whatsapp_admin_interno(p_admin uuid,p_evento uuid,p_accion text,p_envio uuid DEFAULT NULL,p_pagina integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE envio public.whatsapp_envios_invitacion%ROWTYPE; contexto jsonb; lista jsonb;
BEGIN
 IF p_evento IS NULL OR p_evento NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid)
 OR NOT EXISTS(SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
 WHERE u.id=p_admin AND u.activo AND u.rol='administrador' AND ue.activo AND ue.evento_id=p_evento)
 OR (auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin) THEN RAISE EXCEPTION 'sin_permiso'; END IF;
 IF p_accion='reintentar' THEN
 SELECT w.* INTO envio FROM public.whatsapp_envios_invitacion w
 JOIN public.invitaciones i ON i.id=w.invitacion_id JOIN public.registros r ON r.id=i.registro_id
 WHERE w.id=p_envio AND r.evento_id=p_evento;
 IF NOT FOUND THEN RAISE EXCEPTION 'reintento_no_permitido'; END IF;
 contexto:=public.whatsapp_contexto_interno(envio.invitacion_id);
 SELECT * INTO envio FROM public.whatsapp_envios_invitacion WHERE id=p_envio FOR UPDATE;
 IF NOT FOUND OR envio.automatizacion_version IS DISTINCT FROM 1 OR envio.estado IS DISTINCT FROM 'fallido' OR envio.meta_message_id IS NOT NULL
 OR envio.inicio_meta_at IS NOT NULL OR envio.intentos>=3 OR (envio.meta_media_id IS NOT NULL AND envio.media_eliminado_at IS NULL) THEN RAISE EXCEPTION 'reintento_no_permitido'; END IF;
 IF contexto->>'elegible' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'no_elegible'; END IF;
 UPDATE public.whatsapp_envios_invitacion SET estado='listo',reserva_id=NULL,
 reservado_at=NULL,siguiente_intento_at=now(),ultimo_error_codigo=NULL,updated_at=now() WHERE id=envio.id;
 INSERT INTO public.auditoria(usuario_id,accion,entidad,entidad_id,detalles)
 VALUES(p_admin,'whatsapp_reintento_manual','whatsapp_envios_invitacion',envio.id,jsonb_build_object('evento_id',p_evento));
 RETURN jsonb_build_object('ok',true);
 ELSIF p_accion IS DISTINCT FROM 'listar' THEN RAISE EXCEPTION 'accion_invalida'; END IF;
 IF p_pagina IS NULL OR p_pagina<1 OR p_pagina>100000 THEN RAISE EXCEPTION 'pagina_invalida'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(filas)),'[]'::jsonb) INTO lista FROM (
 SELECT r.folio, w.id,w.intentos,w.aceptado_at,w.entregado_at,w.leido_at,
 CASE WHEN c.aceptado_at IS NULL OR c.retirado_at IS NOT NULL THEN 'sin_consentimiento'
 ELSE CASE w.estado WHEN 'listo' THEN 'pendiente' WHEN 'enviando' THEN 'procesando' WHEN 'aceptado_meta' THEN 'aceptado' WHEN 'revision' THEN 'incierto' WHEN 'pendiente_consentimiento' THEN 'sin_consentimiento' ELSE coalesce(w.estado,'no_preparado') END END AS estado,
 w.ultimo_error_codigo,
 (w.automatizacion_version=1 AND w.estado='fallido' AND w.inicio_meta_at IS NULL AND w.meta_message_id IS NULL AND w.intentos<3 AND (w.meta_media_id IS NULL OR w.media_eliminado_at IS NOT NULL)
 AND c.aceptado_at IS NOT NULL AND c.retirado_at IS NULL) AS puede_reintentar
 FROM public.registros r
 LEFT JOIN public.whatsapp_consentimientos_invitacion c ON c.registro_id=r.id
 LEFT JOIN public.invitaciones i ON i.registro_id=r.id AND i.estado IN ('activa','emitida')
 LEFT JOIN public.whatsapp_envios_invitacion w ON w.invitacion_id=i.id AND w.plantilla='amor_invitacion_confirmada_v1'
 WHERE r.evento_id=p_evento AND r.estado='confirmado' AND r.es_prueba=false
 ORDER BY r.id LIMIT 50 OFFSET (p_pagina-1)*50
 ) filas;
 RETURN jsonb_build_object('ok',true,'filas',lista,'pagina',p_pagina,'limite',50);
END $$;
REVOKE ALL ON FUNCTION public.whatsapp_admin_interno(uuid,uuid,text,uuid,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_admin_interno(uuid,uuid,text,uuid,integer) TO service_role;
COMMIT;
