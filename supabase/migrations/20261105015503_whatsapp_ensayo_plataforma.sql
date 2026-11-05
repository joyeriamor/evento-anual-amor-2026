-- Ensayo de un solo uso; no sustituye funciones operativas ni habilita la cola general.
BEGIN;
CREATE TABLE public.whatsapp_ensayo_plataforma (
 id uuid PRIMARY KEY CHECK(id='2bba9e9e-8751-49df-b1bb-17a82c7120d3'::uuid),
 administrador_id uuid NOT NULL REFERENCES public.usuarios(id),
 registro_id uuid NOT NULL UNIQUE REFERENCES public.registros(id),
 invitacion_id uuid UNIQUE REFERENCES public.invitaciones(id),
 envio_id uuid UNIQUE REFERENCES public.whatsapp_envios_invitacion(id),
 telefono text NOT NULL CHECK(encode(sha256(convert_to(telefono,'UTF8')),'hex')='e52c6229f3e0841ae55fd4f5ca575719a5c4a989ba9cf5b8151f6c953e30b8e9'),
 creado_at timestamptz NOT NULL DEFAULT now(),
 vence_at timestamptz NOT NULL DEFAULT now()+interval '2 hours',
 cerrado_at timestamptz
);
ALTER TABLE public.whatsapp_ensayo_plataforma ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.whatsapp_ensayo_plataforma FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.whatsapp_ensayo_control_interno(p_admin uuid,p_accion text,p_datos jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 run constant uuid:='2bba9e9e-8751-49df-b1bb-17a82c7120d3';
 evento constant uuid:='3dc92160-79af-4bf7-b770-263038e88900';
 t public.whatsapp_ensayo_plataforma%ROWTYPE;
 r public.registros%ROWTYPE; i public.invitaciones%ROWTYPE;
 w public.whatsapp_envios_invitacion%ROWTYPE;
 persona public.promotoras%ROWTYPE;
 asesor uuid; resultado jsonb; token text; reserva uuid; telefono text;
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'solo_backend'; END IF;
 IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin THEN RAISE EXCEPTION 'identidad_incorrecta'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
 WHERE u.id=p_admin AND u.rol='administrador' AND u.activo IS TRUE AND ue.evento_id=evento AND ue.activo IS TRUE)
 THEN RAISE EXCEPTION 'sin_asignacion_chiapas'; END IF;
 IF p_accion IS NULL OR p_accion NOT IN ('crear','confirmar','reservar','contexto','autorizar','medio','medio_eliminado','finalizar','estado','cerrar','permiso')
 THEN RAISE EXCEPTION 'accion_invalida'; END IF;
 IF p_accion='permiso' THEN RETURN jsonb_build_object('ok',true); END IF;
 -- Serializa SOLO este ensayo, sin bloquear la operación de ningún evento.
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('whatsapp-ensayo-'||run::text,0));
 SELECT * INTO t FROM public.whatsapp_ensayo_plataforma WHERE id=run FOR UPDATE;
 IF NOT FOUND THEN
  IF p_accion<>'crear' THEN RAISE EXCEPTION 'ensayo_no_creado'; END IF;
  telefono:=p_datos->>'telefono';
  IF telefono IS NULL OR encode(sha256(convert_to(telefono,'UTF8')),'hex')<>'e52c6229f3e0841ae55fd4f5ca575719a5c4a989ba9cf5b8151f6c953e30b8e9'
  THEN RAISE EXCEPTION 'destinatario_no_autorizado'; END IF;
  IF p_datos->>'foto_path' IS DISTINCT FROM evento::text||'/pruebas/'||run::text||'.png' THEN RAISE EXCEPTION 'archivo_no_autorizado'; END IF;
  SELECT id INTO asesor FROM public.asesores WHERE activo IS TRUE AND upper(btrim(nombre))<>'EMPLEADO' ORDER BY id LIMIT 1;
  IF asesor IS NULL THEN RAISE EXCEPTION 'sin_asesor_activo'; END IF;
  resultado:=public.crear_registro_prueba_admin_chiapas(evento,asesor,'PRUEBA WHATSAPP PLATAFORMA',
   'ENSAYO 20261104','Chiapas',right(telefono,10),'promotora','PRUEBA WHATSAPP',p_datos->>'foto_path',NULL,NULL,NULL);
  IF resultado->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'alta_prueba_rechazada'; END IF;
  INSERT INTO public.whatsapp_ensayo_plataforma(id,administrador_id,registro_id,telefono)
  VALUES(run,p_admin,(resultado->>'registro_id')::uuid,telefono) RETURNING * INTO t;
  INSERT INTO public.whatsapp_consentimientos_invitacion(registro_id,aceptado_at,origen,aviso_version,evidencia_referencia,registrado_por)
  VALUES(t.registro_id,now(),'confirmacion_directa','whatsapp_invitacion_v1','Ensayo solicitado por el titular en chat; destinatario permitido por hash',p_admin);
 END IF;
 IF t.administrador_id IS DISTINCT FROM p_admin THEN RAISE EXCEPTION 'ensayo_de_otro_operador'; END IF;
 SELECT * INTO r FROM public.registros WHERE id=t.registro_id FOR UPDATE;
 SELECT * INTO persona FROM public.promotoras WHERE id=r.promotora_id;
 IF r.evento_id IS DISTINCT FROM evento OR r.es_prueba IS DISTINCT FROM true
 OR persona.nombres IS DISTINCT FROM 'PRUEBA WHATSAPP PLATAFORMA' OR persona.apellidos IS DISTINCT FROM 'ENSAYO 20261104'
 OR '52'||persona.telefono_whatsapp IS DISTINCT FROM t.telefono
 THEN RAISE EXCEPTION 'fixture_no_coincide'; END IF;
 IF p_accion NOT IN ('estado','cerrar','finalizar','medio_eliminado') AND (t.cerrado_at IS NOT NULL OR t.vence_at<now()) THEN RAISE EXCEPTION 'ensayo_cerrado_o_caducado'; END IF;
 IF p_accion='confirmar' AND t.invitacion_id IS NULL THEN
  IF r.estado<>'pendiente' THEN RAISE EXCEPTION 'estado_prueba_invalido'; END IF;
  -- Función REAL existente: autoriza cortesía, audita y emite QR cifrado en Vault.
  PERFORM public.autorizar_cortesia_admin_chiapas(r.id,p_admin);
  SELECT * INTO i FROM public.invitaciones WHERE registro_id=r.id AND estado IN ('activa','emitida') ORDER BY emitida_at DESC,id DESC LIMIT 1;
  IF i.id IS NULL THEN RAISE EXCEPTION 'sin_invitacion'; END IF;
  -- NULL queda expresamente fuera del selector operativo automatizacion_version=1.
  INSERT INTO public.whatsapp_envios_invitacion(invitacion_id,plantilla,idioma,estado,consentimiento_confirmado_at,automatizacion_version)
  VALUES(i.id,'amor_invitacion_confirmada_v1','es_MX','listo',now(),NULL) RETURNING * INTO w;
  UPDATE public.whatsapp_ensayo_plataforma SET invitacion_id=i.id,envio_id=w.id WHERE id=run RETURNING * INTO t;
 END IF;
 SELECT * INTO w FROM public.whatsapp_envios_invitacion WHERE id=t.envio_id FOR UPDATE;
 IF t.envio_id IS NOT NULL AND (w.invitacion_id IS DISTINCT FROM t.invitacion_id OR w.automatizacion_version IS NOT NULL) THEN RAISE EXCEPTION 'cola_operativa_prohibida'; END IF;
 IF p_accion='reservar' THEN
  IF w.estado IS DISTINCT FROM 'listo' OR w.intentos<>0 THEN RETURN NULL; END IF;
  reserva:=gen_random_uuid();
  UPDATE public.whatsapp_envios_invitacion SET estado='enviando',intentos=1,reserva_id=reserva,reservado_at=now(),modo_automatizacion='real',updated_at=now()
  WHERE id=w.id;
  RETURN jsonb_build_object('id',w.id,'invitacion_id',t.invitacion_id,'reserva_id',reserva);
 END IF;
 IF p_accion IN ('contexto','autorizar') THEN
  IF w.estado IS DISTINCT FROM 'enviando' OR w.reservado_at<now()-interval '10 minutes'
  OR w.reserva_id IS DISTINCT FROM (p_datos->>'reserva_id')::uuid
  OR (p_datos->>'invitacion_id')::uuid IS DISTINCT FROM t.invitacion_id
  THEN RETURN jsonb_build_object('elegible',false,'codigo','reserva_invalida'); END IF;
  SELECT * INTO r FROM public.registros WHERE id=t.registro_id;
  SELECT * INTO i FROM public.invitaciones WHERE id=t.invitacion_id AND registro_id=r.id;
  IF r.estado IS DISTINCT FROM 'confirmado' OR r.exento_pago IS DISTINCT FROM true
  OR i.estado NOT IN ('emitida','activa') OR i.token_vault_id IS NULL
  THEN RETURN jsonb_build_object('elegible',false,'codigo','prueba_no_confirmada'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.whatsapp_consentimientos_invitacion WHERE registro_id=r.id AND aceptado_at IS NOT NULL AND retirado_at IS NULL)
  THEN RETURN jsonb_build_object('elegible',false,'codigo','sin_consentimiento'); END IF;
  SELECT decrypted_secret INTO token FROM vault.decrypted_secrets WHERE id=i.token_vault_id;
  IF token IS NULL OR encode(sha256(convert_to(token,'UTF8')),'hex') IS DISTINCT FROM i.token_hash
  THEN RETURN jsonb_build_object('elegible',false,'codigo','qr_no_recuperable'); END IF;
  IF p_accion='autorizar' THEN UPDATE public.whatsapp_envios_invitacion SET inicio_meta_at=now() WHERE id=w.id; END IF;
  RETURN jsonb_build_object('elegible',true,'invitacion_id',i.id,'registro_id',r.id,'evento_id',evento,
   'token_qr',token,'telefono',t.telefono,'folio',r.folio,'participante','PRUEBA WHATSAPP PLATAFORMA',
   'evento','Fiesta Anual AMOR 2026 - ENSAYO','fecha','19 de diciembre de 2026',
   'recepcion','Por confirmar','lugar','Salón BIANCO, Tuxtla Gutiérrez, Chiapas');
 END IF;
 IF p_accion IN ('medio','medio_eliminado','finalizar') THEN
  IF w.id IS NULL OR (p_accion<>'medio_eliminado' AND w.estado<>'enviando') OR w.reserva_id IS DISTINCT FROM (p_datos->>'reserva_id')::uuid THEN RETURN 'false'::jsonb; END IF;
  IF p_accion='medio' THEN RETURN to_jsonb(public.whatsapp_guardar_medio_interno(w.id,w.reserva_id,p_datos->>'media_id')); END IF;
  IF p_accion='medio_eliminado' THEN RETURN to_jsonb(public.whatsapp_marcar_medio_eliminado_interno(w.id,w.reserva_id,p_datos->>'media_id')); END IF;
  RETURN to_jsonb(public.whatsapp_finalizar_interno(w.id,w.reserva_id,p_datos->>'fase',p_datos->>'codigo',p_datos->>'message_id'));
 END IF;
 IF p_accion='cerrar' THEN
  IF w.estado='enviando' THEN RAISE EXCEPTION 'envio_en_curso_no_cerrar'; END IF;
  UPDATE public.registros SET estado='cancelado' WHERE id=r.id;
  UPDATE public.invitaciones SET estado='revocada',revocada_at=now() WHERE id=t.invitacion_id AND registro_id=r.id;
  UPDATE public.whatsapp_ensayo_plataforma SET cerrado_at=coalesce(cerrado_at,now()) WHERE id=run RETURNING * INTO t;
 END IF;
 SELECT * INTO r FROM public.registros WHERE id=t.registro_id;
 SELECT * INTO w FROM public.whatsapp_envios_invitacion WHERE id=t.envio_id;
 RETURN jsonb_build_object('ok',true,'ensayo_id',t.id,'registro_id',r.id,'folio',r.folio,'estado_registro',r.estado,
 'es_prueba',r.es_prueba,'invitacion_id',t.invitacion_id,'envio_id',t.envio_id,'estado_envio',w.estado,
 'intentos',coalesce(w.intentos,0),'entregado_at',w.entregado_at,'leido_at',w.leido_at,'cerrado',t.cerrado_at IS NOT NULL);
END $$;
REVOKE ALL ON FUNCTION public.whatsapp_ensayo_control_interno(uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_ensayo_control_interno(uuid,text,jsonb) TO service_role;
COMMIT;
