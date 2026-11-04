-- Paquete WhatsApp local; no activa Meta ni modifica estados de inscripcion.
BEGIN;

-- FUENTE: sql/whatsapp/00_preflight.sql
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


-- FUENTE: sql/whatsapp/01_automatizacion_propuesta.sql
-- PROPUESTA LOCAL. No aplicar antes de completar la auditoría del catálogo real.
-- Usa las tablas existentes. No habilita envíos, no programa trabajos ni reemite QR.

ALTER TABLE public.whatsapp_envios_invitacion
 ADD COLUMN automatizacion_version smallint CHECK (automatizacion_version=1),
 ADD COLUMN reserva_id uuid,
 ADD COLUMN modo_automatizacion text CHECK (modo_automatizacion IN ('simulacion','real')),
 ADD COLUMN inicio_meta_at timestamptz,
 ADD COLUMN meta_media_id text CHECK(meta_media_id ~ '^[0-9]{1,40}$'),
 ADD COLUMN media_subido_at timestamptz,
 ADD COLUMN media_eliminado_at timestamptz,
 ADD COLUMN media_limpieza_reserva uuid,
 ADD COLUMN media_limpieza_reservada_at timestamptz,
 ADD COLUMN media_limpieza_intentos integer NOT NULL DEFAULT 0 CHECK(media_limpieza_intentos BETWEEN 0 AND 3);
-- Reuse audited existing states; only add the explicit non-delivery simulation result.
ALTER TABLE public.whatsapp_envios_invitacion DROP CONSTRAINT whatsapp_envios_estado_chk;
ALTER TABLE public.whatsapp_envios_invitacion ADD CONSTRAINT whatsapp_envios_estado_chk CHECK
 (estado IN ('pendiente_consentimiento','listo','enviando','aceptado_meta','entregado','leido','fallido','cancelado','revision','simulado'));
-- Historical jobs have no automation version and are never claimed blindly.
CREATE INDEX whatsapp_cola_automatizacion_idx ON public.whatsapp_envios_invitacion
 (siguiente_intento_at,created_at) WHERE estado='listo';

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
 INSERT INTO public.whatsapp_envios_invitacion AS w
 (invitacion_id,plantilla,idioma,estado,automatizacion_version,consentimiento_confirmado_at)
 VALUES(p_invitacion_id,'amor_invitacion_confirmada_v1','es_MX','listo',
 1,(contexto->>'consentimiento_at')::timestamptz)
 ON CONFLICT(invitacion_id,plantilla) DO UPDATE SET
 estado='listo',automatizacion_version=1,consentimiento_confirmado_at=excluded.consentimiento_confirmado_at,updated_at=now()
 WHERE w.automatizacion_version IS NULL AND w.estado='pendiente_consentimiento'
 AND w.intentos=0 AND w.meta_message_id IS NULL AND w.reservado_at IS NULL;
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
 UPDATE public.whatsapp_envios_invitacion SET estado='revision',
 ultimo_error_codigo='reserva_caducada',ultimo_error_resumen='Requiere conciliación manual',updated_at=now()
 WHERE estado='enviando' AND automatizacion_version=1 AND reservado_at<now()-interval '10 minutes';
 SELECT * INTO trabajo FROM public.whatsapp_envios_invitacion
 WHERE estado='listo' AND automatizacion_version=1
 AND plantilla='amor_invitacion_confirmada_v1' AND idioma='es_MX' AND intentos<3
 AND (siguiente_intento_at IS NULL OR siguiente_intento_at<=now())
 ORDER BY created_at,id FOR UPDATE SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 reserva:=gen_random_uuid();
 UPDATE public.whatsapp_envios_invitacion SET estado='enviando',
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
 UPDATE public.whatsapp_envios_invitacion SET estado=CASE p_fase WHEN 'aceptado' THEN 'aceptado_meta' WHEN 'incierto' THEN 'revision' WHEN 'sin_consentimiento' THEN 'pendiente_consentimiento' ELSE p_fase END,
 meta_message_id=p_message_id,aceptado_at=CASE WHEN p_fase='aceptado' THEN now() END,
 ultimo_error_codigo=p_codigo,ultimo_error_resumen=NULL,updated_at=now()
 WHERE id=p_id AND reserva_id=p_reserva AND estado='enviando';
 IF NOT FOUND THEN RETURN false; END IF;
 IF p_fase='aceptado' THEN PERFORM public.whatsapp_conciliar_entrega_interno(p_message_id); END IF;
 RETURN true;
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
 IF NOT FOUND OR trabajo.estado IS DISTINCT FROM 'enviando'
 OR trabajo.reserva_id IS DISTINCT FROM p_reserva OR trabajo.inicio_meta_at IS NOT NULL
 OR trabajo.reservado_at IS NULL OR trabajo.reservado_at<now()-interval '10 minutes' THEN
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


-- FUENTE: sql/whatsapp/02_administracion_propuesta.sql

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


-- FUENTE: sql/whatsapp/03_webhook_propuesta.sql

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


-- FUENTE: sql/whatsapp/04_consulta_privada_propuesta.sql

-- Only reads the existing QR. Never calls an emitter, inserts an invitation or creates a Vault secret.
CREATE FUNCTION public.whatsapp_qr_admin_interno(p_invitacion uuid,p_admin uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.invitaciones%ROWTYPE;r public.registros%ROWTYPE;token text;
BEGIN
 SELECT * INTO i FROM public.invitaciones WHERE id=p_invitacion;
 SELECT * INTO r FROM public.registros WHERE id=i.registro_id FOR SHARE;
 IF NOT FOUND OR r.estado IS DISTINCT FROM 'confirmado' OR r.es_prueba IS DISTINCT FROM false
 OR r.evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid)
 OR NOT EXISTS(SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
 WHERE u.id=p_admin AND u.activo AND u.rol='administrador' AND ue.activo AND ue.evento_id=r.evento_id)
 OR (auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin)
 THEN RAISE EXCEPTION 'sin_permiso'; END IF;
 IF NOT COALESCE(r.exento_pago,false) AND NOT EXISTS(SELECT 1 FROM public.pagos WHERE registro_id=r.id AND estado='validado')
 THEN RAISE EXCEPTION 'registro_no_elegible'; END IF;
 SELECT * INTO i FROM public.invitaciones WHERE id=p_invitacion AND registro_id=r.id FOR SHARE;
 IF NOT FOUND OR i.estado NOT IN ('activa','emitida') OR i.token_vault_id IS NULL THEN RAISE EXCEPTION 'qr_no_vigente'; END IF;
 SELECT decrypted_secret INTO token FROM vault.decrypted_secrets WHERE id=i.token_vault_id;
 IF token IS NULL OR encode(sha256(convert_to(token,'UTF8')),'hex') IS DISTINCT FROM i.token_hash
 THEN RAISE EXCEPTION 'qr_no_recuperable'; END IF;
 RETURN jsonb_build_object('invitacion_id',i.id,'token_qr',token,'ya_existia',true);
END $$;

-- Preserves the admin endpoint contract, without direct table grants or returning a QR token.
CREATE FUNCTION public.whatsapp_preparar_admin_interno(p_registro uuid,p_admin uuid,p_preparar boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.registros%ROWTYPE;i public.invitaciones%ROWTYPE;
 c public.whatsapp_consentimientos_invitacion%ROWTYPE;w public.whatsapp_envios_invitacion%ROWTYPE;
BEGIN
 SELECT * INTO r FROM public.registros WHERE id=p_registro FOR SHARE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
 WHERE u.id=p_admin AND u.activo AND u.rol='administrador' AND ue.activo AND ue.evento_id=r.evento_id)
 OR (auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin) THEN RAISE EXCEPTION 'sin_permiso'; END IF;
 IF r.evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid) OR r.estado IS DISTINCT FROM 'confirmado' OR r.es_prueba IS DISTINCT FROM false THEN RAISE EXCEPTION 'registro_no_elegible'; END IF;
 IF NOT COALESCE(r.exento_pago,false) AND NOT EXISTS(SELECT 1 FROM public.pagos WHERE registro_id=r.id AND estado='validado') THEN RAISE EXCEPTION 'registro_no_elegible'; END IF;
 SELECT * INTO i FROM public.invitaciones WHERE registro_id=r.id AND estado IN ('activa','emitida')
 ORDER BY emitida_at DESC NULLS LAST,id DESC LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'qr_no_vigente'; END IF;
 SELECT * INTO c FROM public.whatsapp_consentimientos_invitacion WHERE registro_id=r.id;
 IF p_preparar IS TRUE THEN PERFORM public.whatsapp_encolar_interno(i.id); END IF;
 SELECT * INTO w FROM public.whatsapp_envios_invitacion WHERE invitacion_id=i.id AND plantilla='amor_invitacion_confirmada_v1';
 RETURN jsonb_build_object('ok',true,'modo',CASE WHEN p_preparar THEN 'preparado_sin_envio' ELSE 'solo_consulta' END,
 'registro_id',r.id,'evento_id',r.evento_id,'tipo',CASE WHEN r.exento_pago THEN 'cortesia' ELSE 'pago_validado' END,
 'invitacion_id',i.id,'plantilla','amor_invitacion_confirmada_v1','estado_whatsapp',coalesce(w.estado,'no_preparado'),
 'consentimiento_registrado',c.aceptado_at IS NOT NULL AND c.retirado_at IS NULL,
 'consentimiento_estado',CASE WHEN c.aceptado_at IS NULL THEN 'no_registrado' WHEN c.retirado_at IS NOT NULL THEN 'retirado' ELSE 'vigente' END,
 'entrega_automatica_habilitada',false,'nota','Consulta o preparación sin invocar Meta.');
END $$;
REVOKE ALL ON FUNCTION public.whatsapp_qr_admin_interno(uuid,uuid),public.whatsapp_preparar_admin_interno(uuid,uuid,boolean)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_qr_admin_interno(uuid,uuid),public.whatsapp_preparar_admin_interno(uuid,uuid,boolean) TO service_role;


-- FUENTE: sql/whatsapp/05_medios_privados_propuesta.sql

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
