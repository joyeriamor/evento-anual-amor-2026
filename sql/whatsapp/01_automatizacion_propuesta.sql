-- PROPUESTA LOCAL. No aplicar antes de completar la auditoría del catálogo real.
-- Usa las tablas existentes. No habilita envíos, no programa trabajos ni reemite QR.
BEGIN;
ALTER TABLE public.whatsapp_envios_invitacion
 ADD COLUMN fase_automatizacion text,
 ADD COLUMN reserva_id uuid,
 ADD COLUMN modo_automatizacion text,
 ADD COLUMN inicio_meta_at timestamptz,
 ADD CONSTRAINT whatsapp_fase_automatizacion_check CHECK (fase_automatizacion IN
 ('pendiente','procesando','aceptado','fallido','incierto','simulado','sin_consentimiento','cancelado','entregado','leido')),
 ADD CONSTRAINT whatsapp_modo_automatizacion_check CHECK (modo_automatizacion IN ('simulacion','real'));
-- Las filas históricas conservan fase NULL: no se procesan ni se presume consentimiento.
CREATE INDEX whatsapp_cola_automatizacion_idx ON public.whatsapp_envios_invitacion
 (siguiente_intento_at,created_at) WHERE fase_automatizacion='pendiente';

CREATE FUNCTION public.whatsapp_contexto_interno(p_invitacion_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.invitaciones%ROWTYPE; r public.registros%ROWTYPE;
 c public.whatsapp_consentimientos_invitacion%ROWTYPE; p public.promotoras%ROWTYPE;
 telefono text; token text; fecha text; lugar text; recepcion text;
BEGIN
 SELECT * INTO i FROM public.invitaciones WHERE id=p_invitacion_id;
 IF NOT FOUND OR i.estado NOT IN ('activa','emitida') OR i.token_vault_id IS NULL THEN
  RETURN jsonb_build_object('elegible',false,'codigo','qr_no_vigente'); END IF;
 SELECT * INTO r FROM public.registros WHERE id=i.registro_id FOR SHARE;
 IF NOT FOUND OR r.estado IS DISTINCT FROM 'confirmado' OR r.es_prueba IS DISTINCT FROM false
 OR r.evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid)
 THEN RETURN jsonb_build_object('elegible',false,'codigo','registro_no_elegible'); END IF;
 -- Same lock order as the original approval routines: registro before invitacion.
 SELECT * INTO i FROM public.invitaciones WHERE id=p_invitacion_id AND registro_id=r.id FOR SHARE;
 IF NOT FOUND OR i.estado NOT IN ('activa','emitida') OR i.token_vault_id IS NULL THEN
 RETURN jsonb_build_object('elegible',false,'codigo','qr_no_vigente'); END IF;
 IF NOT COALESCE(r.exento_pago,false) AND NOT EXISTS
 (SELECT 1 FROM public.pagos WHERE registro_id=r.id AND estado='validado') THEN
 RETURN jsonb_build_object('elegible',false,'codigo','sin_autorizacion'); END IF;
 SELECT * INTO c FROM public.whatsapp_consentimientos_invitacion WHERE registro_id=r.id FOR SHARE;
 IF NOT FOUND OR c.aceptado_at IS NULL OR c.retirado_at IS NOT NULL THEN
 RETURN jsonb_build_object('elegible',false,'codigo','sin_consentimiento'); END IF;
 SELECT * INTO p FROM public.promotoras WHERE id=r.promotora_id;
 telefono:=regexp_replace(p.telefono_whatsapp,'[^0-9]','','g');
 IF length(telefono)=10 THEN telefono:='52'||telefono; END IF;
 IF telefono IS NULL OR telefono !~ '^52[1-9][0-9]{9}$' THEN
 RETURN jsonb_build_object('elegible',false,'codigo','telefono_invalido'); END IF;
 SELECT decrypted_secret INTO token FROM vault.decrypted_secrets WHERE id=i.token_vault_id;
 IF token IS NULL OR encode(sha256(convert_to(token,'UTF8')),'hex') IS DISTINCT FROM i.token_hash THEN
 RETURN jsonb_build_object('elegible',false,'codigo','qr_no_recuperable'); END IF;
 IF r.evento_id='43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN
 fecha:='6 de diciembre de 2026'; lugar:='Salón RADEV''S 1, Minatitlán, Veracruz'; recepcion:='1:00 p. m.';
 ELSE fecha:='19 de diciembre de 2026'; lugar:='Salón BIANCO, Tuxtla Gutiérrez, Chiapas'; recepcion:='Por confirmar'; END IF;
 RETURN jsonb_build_object('elegible',true,'invitacion_id',i.id,'registro_id',r.id,
 'evento_id',r.evento_id,'token_qr',token,'telefono',telefono,'folio',r.folio,
 'participante',btrim(concat_ws(' ',p.nombres,p.apellidos)),
 'evento','Fiesta Anual AMOR 2026','fecha',fecha,'recepcion',recepcion,'lugar',lugar,
 'consentimiento_at',c.aceptado_at);
END $$;

CREATE FUNCTION public.whatsapp_encolar_interno(p_invitacion_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE contexto jsonb;
BEGIN
 contexto:=public.whatsapp_contexto_interno(p_invitacion_id);
 IF contexto->>'elegible' IS DISTINCT FROM 'true' THEN RETURN false; END IF;
 INSERT INTO public.whatsapp_envios_invitacion
 (invitacion_id,plantilla,idioma,estado,fase_automatizacion,consentimiento_confirmado_at)
 VALUES(p_invitacion_id,'amor_invitacion_confirmada_v1','es_MX','pendiente_consentimiento',
 'pendiente',(contexto->>'consentimiento_at')::timestamptz)
 ON CONFLICT(invitacion_id,plantilla) DO NOTHING;
 RETURN FOUND;
END $$;

CREATE FUNCTION public.whatsapp_al_confirmar_interno()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE invitacion uuid;
BEGIN
 BEGIN
 IF TG_TABLE_NAME='invitaciones' THEN invitacion:=NEW.id;
 ELSE SELECT id INTO invitacion FROM public.invitaciones WHERE registro_id=NEW.id
 AND estado IN ('activa','emitida') ORDER BY emitida_at DESC NULLS LAST,id DESC LIMIT 1; END IF;
 IF invitacion IS NOT NULL THEN PERFORM public.whatsapp_encolar_interno(invitacion); END IF;
 EXCEPTION WHEN OTHERS THEN
 -- Fallo cerrado en WhatsApp; la aprobación original conserva su resultado.
 -- No registrar SQLERRM, tokens, teléfono ni contenido del contexto.
 RAISE WARNING 'whatsapp_preparacion_no_disponible';
 END;
 RETURN NEW;
END $$;
CREATE TRIGGER whatsapp_invitacion_confirmada AFTER INSERT ON public.invitaciones
 FOR EACH ROW EXECUTE FUNCTION public.whatsapp_al_confirmar_interno();
CREATE TRIGGER whatsapp_registro_confirmado AFTER UPDATE OF estado,exento_pago ON public.registros
 FOR EACH ROW WHEN (NEW.estado='confirmado') EXECUTE FUNCTION public.whatsapp_al_confirmar_interno();

CREATE FUNCTION public.whatsapp_reservar_interno(p_modo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE trabajo public.whatsapp_envios_invitacion%ROWTYPE; reserva uuid;
BEGIN
 IF p_modo IS NULL OR p_modo NOT IN ('simulacion','real') THEN RAISE EXCEPTION 'modo_invalido'; END IF;
 -- Nunca reencolar reservas caducadas: un proceso pudo haber llamado a Meta.
 UPDATE public.whatsapp_envios_invitacion SET fase_automatizacion='incierto',
 ultimo_error_codigo='reserva_caducada',ultimo_error_resumen='Requiere conciliación manual',updated_at=now()
 WHERE fase_automatizacion='procesando' AND reservado_at<now()-interval '10 minutes';
 SELECT * INTO trabajo FROM public.whatsapp_envios_invitacion
 WHERE fase_automatizacion='pendiente' AND intentos<3
 AND (siguiente_intento_at IS NULL OR siguiente_intento_at<=now())
 ORDER BY created_at,id FOR UPDATE SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 reserva:=gen_random_uuid();
 UPDATE public.whatsapp_envios_invitacion SET fase_automatizacion='procesando',
 reserva_id=reserva,reservado_at=now(),modo_automatizacion=p_modo,
 inicio_meta_at=NULL,intentos=intentos+1,updated_at=now() WHERE id=trabajo.id;
 RETURN jsonb_build_object('id',trabajo.id,'invitacion_id',trabajo.invitacion_id,'reserva_id',reserva);
END $$;

CREATE FUNCTION public.whatsapp_finalizar_interno(p_id uuid,p_reserva uuid,p_fase text,p_codigo text DEFAULT NULL,p_message_id text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_fase IS NULL OR p_fase NOT IN ('aceptado','fallido','incierto','simulado','sin_consentimiento','cancelado')
 OR (p_codigo IS NOT NULL AND p_codigo !~ '^[a-z0-9_]{1,60}$')
 OR (p_fase='aceptado' AND (p_message_id IS NULL OR length(p_message_id)>255)) THEN RAISE EXCEPTION 'resultado_invalido'; END IF;
 UPDATE public.whatsapp_envios_invitacion SET fase_automatizacion=p_fase,
 meta_message_id=p_message_id,aceptado_at=CASE WHEN p_fase='aceptado' THEN now() END,
 ultimo_error_codigo=p_codigo,ultimo_error_resumen=NULL,updated_at=now()
 WHERE id=p_id AND reserva_id=p_reserva AND fase_automatizacion='procesando';
 RETURN FOUND;
END $$;

-- Validación final bajo bloqueos. No elimina la ventana entre COMMIT y la red:
-- toda revocación observada aquí cancela el envío; documentar esa ventana inevitable.
CREATE FUNCTION public.whatsapp_autorizar_salida_interno(p_id uuid,p_reserva uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE trabajo public.whatsapp_envios_invitacion%ROWTYPE; contexto jsonb;
BEGIN
 SELECT * INTO trabajo FROM public.whatsapp_envios_invitacion WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'reserva_invalida'; END IF;
 contexto:=public.whatsapp_contexto_interno(trabajo.invitacion_id);
 SELECT * INTO trabajo FROM public.whatsapp_envios_invitacion WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR trabajo.fase_automatizacion IS DISTINCT FROM 'procesando'
 OR trabajo.reserva_id IS DISTINCT FROM p_reserva OR trabajo.inicio_meta_at IS NOT NULL THEN
 RAISE EXCEPTION 'reserva_invalida'; END IF;
 IF contexto->>'elegible'='true' THEN
 UPDATE public.whatsapp_envios_invitacion SET inicio_meta_at=now() WHERE id=p_id;
 END IF;
 RETURN contexto;
END $$;

-- Defensa adicional: ninguna operación nueva es ejecutable por clientes.
REVOKE ALL ON FUNCTION public.whatsapp_contexto_interno(uuid),public.whatsapp_encolar_interno(uuid),
 public.whatsapp_al_confirmar_interno(),public.whatsapp_reservar_interno(text),
 public.whatsapp_finalizar_interno(uuid,uuid,text,text,text),public.whatsapp_autorizar_salida_interno(uuid,uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_contexto_interno(uuid),public.whatsapp_encolar_interno(uuid),
 public.whatsapp_reservar_interno(text),public.whatsapp_finalizar_interno(uuid,uuid,text,text,text),
 public.whatsapp_autorizar_salida_interno(uuid,uuid) TO service_role;
COMMIT;
