BEGIN;
-- Minimal signed-status inbox. Not another send queue; no phone, QR, raw payload or credentials.
CREATE TABLE public.whatsapp_webhook_eventos_internos(
 meta_message_id text NOT NULL CHECK(length(meta_message_id)<=255),
 estado text NOT NULL CHECK(estado IN ('delivered','read','failed')),
 fecha timestamptz NOT NULL,recibido_at timestamptz NOT NULL DEFAULT now(),
 aplicado_at timestamptz,PRIMARY KEY(meta_message_id,estado));
ALTER TABLE public.whatsapp_webhook_eventos_internos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.whatsapp_webhook_eventos_internos FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.whatsapp_conciliar_entrega_interno(p_message_id text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE entrega timestamptz;lectura timestamptz;fallo timestamptz;
BEGIN
 SELECT min(fecha) FILTER(WHERE estado='delivered'),min(fecha) FILTER(WHERE estado='read'),min(fecha) FILTER(WHERE estado='failed')
 INTO entrega,lectura,fallo FROM public.whatsapp_webhook_eventos_internos WHERE meta_message_id=p_message_id;
 IF entrega IS NULL AND lectura IS NULL AND fallo IS NULL THEN RETURN false; END IF;
 UPDATE public.whatsapp_envios_invitacion SET
 estado=CASE WHEN leido_at IS NOT NULL OR lectura IS NOT NULL THEN 'leido' WHEN entregado_at IS NOT NULL OR entrega IS NOT NULL THEN 'entregado' ELSE 'fallido' END,
 entregado_at=coalesce(entregado_at,entrega,lectura),leido_at=coalesce(leido_at,lectura),
 ultimo_error_codigo=CASE WHEN fallo IS NOT NULL AND entrega IS NULL AND lectura IS NULL AND entregado_at IS NULL AND leido_at IS NULL THEN 'meta_entrega_fallida' ELSE ultimo_error_codigo END,updated_at=now()
 WHERE meta_message_id=p_message_id AND modo_automatizacion='real'
 AND estado IN ('aceptado_meta','entregado','leido','fallido');
 IF NOT FOUND THEN RETURN false; END IF;
 UPDATE public.whatsapp_webhook_eventos_internos SET aplicado_at=coalesce(aplicado_at,now()) WHERE meta_message_id=p_message_id;
 RETURN true;
END $$;
CREATE FUNCTION public.whatsapp_confirmar_entrega_interno(p_message_id text,p_estado text,p_fecha timestamptz)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_message_id IS NULL OR p_message_id NOT LIKE 'wamid.%' OR length(p_message_id)>255
 OR p_estado IS NULL OR p_estado NOT IN ('delivered','read','failed') OR p_fecha IS NULL OR p_fecha>now()+interval '5 minutes'
 THEN RAISE EXCEPTION 'confirmacion_invalida'; END IF;
 INSERT INTO public.whatsapp_webhook_eventos_internos(meta_message_id,estado,fecha)
 VALUES(p_message_id,p_estado,p_fecha) ON CONFLICT(meta_message_id,estado) DO NOTHING;
 -- Early statuses are safely retained before the sender persists wamid.
 RETURN public.whatsapp_conciliar_entrega_interno(p_message_id);
END $$;
REVOKE ALL ON FUNCTION public.whatsapp_confirmar_entrega_interno(text,text,timestamptz),public.whatsapp_conciliar_entrega_interno(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_confirmar_entrega_interno(text,text,timestamptz) TO service_role;
COMMIT;
