BEGIN;
CREATE FUNCTION public.whatsapp_guardar_medio_interno(p_id uuid,p_reserva uuid,p_media text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_media IS NULL OR p_media !~ '^[0-9]{1,40}$' THEN RAISE EXCEPTION 'media_invalido'; END IF;
 UPDATE public.whatsapp_envios_invitacion SET meta_media_id=p_media,media_subido_at=now(),media_eliminado_at=NULL,
 media_limpieza_intentos=0,updated_at=now()
 WHERE id=p_id AND reserva_id=p_reserva AND estado='enviando' AND inicio_meta_at IS NULL
 AND (meta_media_id IS NULL OR media_eliminado_at IS NOT NULL);
 RETURN FOUND;
END $$;
CREATE FUNCTION public.whatsapp_marcar_medio_eliminado_interno(p_id uuid,p_reserva uuid,p_media text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.whatsapp_envios_invitacion SET media_eliminado_at=now(),updated_at=now()
 WHERE id=p_id AND reserva_id=p_reserva AND meta_media_id=p_media
 AND estado IN ('cancelado','fallido','pendiente_consentimiento');
 RETURN FOUND;
END $$;
CREATE FUNCTION public.whatsapp_reservar_limpieza_interno()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w public.whatsapp_envios_invitacion%ROWTYPE;reserva uuid;
BEGIN
 SELECT * INTO w FROM public.whatsapp_envios_invitacion WHERE automatizacion_version=1
 AND meta_media_id IS NOT NULL AND media_eliminado_at IS NULL AND media_limpieza_intentos<3
 AND (media_limpieza_reservada_at IS NULL OR media_limpieza_reservada_at<now()-interval '10 minutes')
 AND ((estado IN ('fallido','cancelado','pendiente_consentimiento') AND inicio_meta_at IS NULL)
 OR (estado IN ('entregado','leido','fallido') AND media_subido_at<now()-interval '7 days'))
 ORDER BY media_subido_at,id FOR UPDATE SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 reserva:=gen_random_uuid();
 UPDATE public.whatsapp_envios_invitacion SET media_limpieza_reserva=reserva,media_limpieza_reservada_at=now(),
 media_limpieza_intentos=media_limpieza_intentos+1 WHERE id=w.id;
 RETURN jsonb_build_object('id',w.id,'reserva_id',reserva,'media_id',w.meta_media_id);
END $$;
CREATE FUNCTION public.whatsapp_finalizar_limpieza_interno(p_id uuid,p_reserva uuid,p_media text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.whatsapp_envios_invitacion SET media_eliminado_at=now(),updated_at=now()
 WHERE id=p_id AND media_limpieza_reserva=p_reserva AND meta_media_id=p_media AND media_eliminado_at IS NULL;
 RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION public.whatsapp_guardar_medio_interno(uuid,uuid,text),public.whatsapp_marcar_medio_eliminado_interno(uuid,uuid,text),
 public.whatsapp_reservar_limpieza_interno(),public.whatsapp_finalizar_limpieza_interno(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_guardar_medio_interno(uuid,uuid,text),public.whatsapp_marcar_medio_eliminado_interno(uuid,uuid,text),
 public.whatsapp_reservar_limpieza_interno(),public.whatsapp_finalizar_limpieza_interno(uuid,uuid,text) TO service_role;
COMMIT;
