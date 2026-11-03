BEGIN;
CREATE FUNCTION public.whatsapp_confirmar_entrega_interno(p_message_id text,p_estado text,p_fecha timestamptz)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_estado IS NULL OR p_estado NOT IN ('delivered','read') OR p_fecha IS NULL OR p_fecha>now()+interval '5 minutes'
 THEN RAISE EXCEPTION 'confirmacion_invalida'; END IF;
 UPDATE public.whatsapp_envios_invitacion SET
 fase_automatizacion=CASE WHEN leido_at IS NOT NULL OR p_estado='read' THEN 'leido' ELSE 'entregado' END,
 entregado_at=coalesce(entregado_at,p_fecha),
 leido_at=CASE WHEN p_estado='read' THEN coalesce(leido_at,p_fecha) ELSE leido_at END,updated_at=now()
 WHERE meta_message_id=p_message_id AND modo_automatizacion='real'
 AND fase_automatizacion IN ('aceptado','entregado','leido');
 RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION public.whatsapp_confirmar_entrega_interno(text,text,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_confirmar_entrega_interno(text,text,timestamptz) TO service_role;
COMMIT;
