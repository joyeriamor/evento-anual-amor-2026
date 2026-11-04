BEGIN;
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
COMMIT;
