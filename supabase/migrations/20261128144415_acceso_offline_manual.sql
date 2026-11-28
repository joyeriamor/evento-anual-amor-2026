-- Añade solo el ingreso por nombre al módulo offline. No cambia contratos QR ni funciones existentes.
-- Requiere 20261128025528_acceso_offline.sql.
CREATE FUNCTION public.offline_sincronizar_manual(p_evento_id uuid,p_dispositivo_id uuid,p_paquete_id uuid,
 p_operacion_id uuid,p_registro_id uuid,p_invitacion_id uuid,p_ingresado_at timestamptz,
 p_identidad_confirmada boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid; v_paquete public.offline_paquetes%ROWTYPE;
 v_inv public.invitaciones%ROWTYPE; v_reg public.registros%ROWTYPE;
 v_anterior public.offline_operaciones%ROWTYPE;
 v_hash text; v_acceso uuid; v_ingreso timestamptz; v_resultado jsonb;
BEGIN
 v_uid:=public.offline_autorizar(p_evento_id);
 IF p_operacion_id IS NULL OR p_dispositivo_id IS NULL OR p_registro_id IS NULL
    OR p_invitacion_id IS NULL OR p_ingresado_at IS NULL OR p_identidad_confirmada IS DISTINCT FROM true
 THEN RAISE EXCEPTION 'Entrada manual inválida'; END IF;
 SELECT * INTO v_paquete FROM public.offline_paquetes
 WHERE id=p_paquete_id AND evento_id=p_evento_id AND usuario_id=v_uid AND dispositivo_id=p_dispositivo_id
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El paquete no pertenece a esta cuenta, equipo y evento' USING ERRCODE='42501'; END IF;
 -- IDs are selection inputs, not authority: the server binds them to the
 -- invitation list captured for this authenticated user, event and device.
 SELECT * INTO v_inv FROM public.invitaciones
 WHERE id=p_invitacion_id AND registro_id=p_registro_id;
 IF NOT FOUND OR NOT(v_inv.id=ANY(v_paquete.invitaciones))
 THEN RETURN jsonb_build_object('ok',false,'estado','qr_fuera_del_paquete'); END IF;
 v_hash:=v_inv.token_hash;
 IF v_hash IS NULL OR v_hash !~ '^[a-f0-9]{64}$'
 THEN RETURN jsonb_build_object('ok',false,'estado','no_autorizado_actualmente'); END IF;
 SELECT * INTO v_anterior FROM public.offline_operaciones
 WHERE paquete_id=p_paquete_id AND operacion_id=p_operacion_id;
 IF FOUND THEN
  IF v_anterior.token_hash<>v_hash OR v_anterior.ingresado_at<>p_ingresado_at
     OR v_anterior.resultado->>'origen' IS DISTINCT FROM 'nombre'
     OR v_anterior.resultado->>'registro_id' IS DISTINCT FROM p_registro_id::text
     OR v_anterior.resultado->>'invitacion_id' IS DISTINCT FROM p_invitacion_id::text
  THEN RAISE EXCEPTION 'Identificador de operación reutilizado con otros datos'; END IF;
  RETURN v_anterior.resultado;
 END IF;
 IF clock_timestamp()>v_paquete.expira_at+interval '7 days'
    OR p_ingresado_at<v_paquete.creado_at-interval '5 minutes'
    OR p_ingresado_at>v_paquete.expira_at OR p_ingresado_at>clock_timestamp()+interval '5 minutes'
 THEN RETURN jsonb_build_object('ok',false,'estado','fecha_fuera_de_rango'); END IF;
 SELECT * INTO v_reg FROM public.registros WHERE id=v_inv.registro_id AND evento_id=p_evento_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'estado','registro_inexistente'); END IF;
 -- Same lock order as existing online entry: registration, then invitation.
 SELECT * INTO v_inv FROM public.invitaciones WHERE id=p_invitacion_id AND registro_id=v_reg.id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'estado','no_autorizado_actualmente'); END IF;
 SELECT ac.id,ac.ingresado_at INTO v_acceso,v_ingreso
 FROM public.accesos ac JOIN public.invitaciones ai ON ai.id=ac.invitacion_id
 WHERE ai.registro_id=v_reg.id ORDER BY ac.ingresado_at LIMIT 1;
 IF FOUND THEN
  v_resultado:=jsonb_build_object('ok',true,'estado','ya_ingreso','acceso_id',v_acceso,'ingresado_at',v_ingreso);
 ELSE
  IF v_reg.estado IS DISTINCT FROM 'confirmado' OR coalesce(v_inv.estado,'') NOT IN ('emitida','activa')
  THEN RETURN jsonb_build_object('ok',false,'estado','no_autorizado_actualmente'); END IF;
  IF NOT coalesce(v_reg.exento_pago,false) AND NOT EXISTS(
   SELECT 1 FROM public.pagos WHERE registro_id=v_reg.id AND estado='validado')
  THEN RETURN jsonb_build_object('ok',false,'estado','sin_pago'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.promotoras m WHERE m.id=v_reg.promotora_id
      AND nullif(btrim(m.foto_path),'') IS NOT NULL)
  THEN RETURN jsonb_build_object('ok',false,'estado','sin_fotografia'); END IF;
  INSERT INTO public.accesos(invitacion_id,operador_id,ingresado_at)
  VALUES(v_inv.id,v_uid,p_ingresado_at) RETURNING id INTO v_acceso;
  v_resultado:=jsonb_build_object('ok',true,'estado','ingreso_registrado',
    'acceso_id',v_acceso,'ingresado_at',p_ingresado_at);
 END IF;
 v_resultado:=v_resultado || jsonb_build_object('origen','nombre',
   'registro_id',v_reg.id,'invitacion_id',v_inv.id);
 INSERT INTO public.offline_operaciones(paquete_id,operacion_id,token_hash,ingresado_at,resultado)
 VALUES(p_paquete_id,p_operacion_id,v_hash,p_ingresado_at,v_resultado);
 RETURN v_resultado;
END $$;
REVOKE ALL ON FUNCTION public.offline_sincronizar_manual(uuid,uuid,uuid,uuid,uuid,uuid,timestamptz,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.offline_sincronizar_manual(uuid,uuid,uuid,uuid,uuid,uuid,timestamptz,boolean) TO authenticated;
