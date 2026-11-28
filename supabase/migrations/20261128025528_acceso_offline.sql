-- Módulo independiente: no cambia funciones, pagos ni invitaciones de los eventos.
CREATE TABLE public.offline_paquetes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 evento_id uuid NOT NULL REFERENCES public.eventos(id),
 usuario_id uuid NOT NULL REFERENCES public.usuarios(id),
 dispositivo_id uuid NOT NULL,
 creado_at timestamptz NOT NULL DEFAULT now(),
 expira_at timestamptz NOT NULL,
 invitaciones uuid[] NOT NULL,
 CHECK (expira_at > creado_at)
);
CREATE INDEX offline_paquetes_usuario ON public.offline_paquetes(usuario_id,evento_id);
CREATE TABLE public.offline_operaciones (
 paquete_id uuid NOT NULL REFERENCES public.offline_paquetes(id),
 operacion_id uuid NOT NULL,
 token_hash text NOT NULL,
 ingresado_at timestamptz NOT NULL,
 recibido_at timestamptz NOT NULL DEFAULT now(),
 resultado jsonb NOT NULL,
 PRIMARY KEY(paquete_id,operacion_id)
);
ALTER TABLE public.offline_paquetes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offline_operaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.offline_paquetes,public.offline_operaciones FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.offline_autorizar(p_evento_id uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
 IF p_evento_id IS NULL OR p_evento_id NOT IN (
 '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid)
 OR v_uid IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
  WHERE u.id=v_uid AND u.activo IS TRUE AND u.rol IN ('administrador','acceso')
    AND ue.evento_id=p_evento_id AND ue.activo IS TRUE
 ) THEN RAISE EXCEPTION 'Sin permiso activo para este evento' USING ERRCODE='42501'; END IF;
 RETURN v_uid;
END $$;
REVOKE ALL ON FUNCTION public.offline_autorizar(uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.offline_descargar(p_evento_id uuid,p_dispositivo_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid; v_id uuid; v_expira timestamptz; v_creado timestamptz:=clock_timestamp();
 v_filas jsonb; v_invitaciones uuid[];
BEGIN
 v_uid:=public.offline_autorizar(p_evento_id);
 IF p_dispositivo_id IS NULL THEN RAISE EXCEPTION 'Equipo requerido'; END IF;
 SELECT ((e.fecha_inicio AT TIME ZONE 'America/Mexico_City')::date+1)::timestamp
          AT TIME ZONE 'America/Mexico_City'
 INTO v_expira FROM public.eventos e WHERE e.id=p_evento_id;
 IF v_expira IS NULL OR v_expira<=v_creado THEN RAISE EXCEPTION 'El evento ya terminó'; END IF;
 -- A single SQL statement captures the roster; no REST 1000-row truncation.
 WITH filas AS (
 SELECT r.id AS registro_id,r.evento_id,r.folio,
  concat_ws(' ',m.nombres,m.apellidos) AS nombre,coalesce(a.nombre,'') AS asesor,
  coalesce(r.grupo_ruta,m.tipo_participante,'') AS grupo,
  r.estado AS estado_registro,coalesce(r.exento_pago,false) AS exento_pago,
  EXISTS(SELECT 1 FROM public.pagos p WHERE p.registro_id=r.id AND p.estado='validado') AS pago_validado,
  EXISTS(SELECT 1 FROM public.accesos ac JOIN public.invitaciones ai ON ai.id=ac.invitacion_id
         WHERE ai.registro_id=r.id) AS ya_ingreso,
  i.id AS invitacion_id,i.token_hash,i.estado AS estado_invitacion,m.foto_path
 FROM public.registros r
 LEFT JOIN public.promotoras m ON m.id=r.promotora_id
 LEFT JOIN public.asesores a ON a.id=r.asesor_id
 LEFT JOIN LATERAL (
  SELECT iv.id,iv.token_hash,iv.estado FROM public.invitaciones iv WHERE iv.registro_id=r.id
  ORDER BY CASE WHEN iv.estado IN ('emitida','activa') THEN 0 ELSE 1 END,
           iv.emitida_at DESC NULLS LAST,iv.id DESC LIMIT 1
 ) i ON true
 WHERE r.evento_id=p_evento_id AND coalesce(r.es_prueba,false)=false
 )
 SELECT coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.registro_id),'[]'::jsonb),
        coalesce(array_agg(f.invitacion_id) FILTER (WHERE f.invitacion_id IS NOT NULL),'{}'::uuid[])
 INTO v_filas,v_invitaciones FROM filas f;
 INSERT INTO public.offline_paquetes(evento_id,usuario_id,dispositivo_id,creado_at,expira_at,invitaciones)
 VALUES(p_evento_id,v_uid,p_dispositivo_id,v_creado,v_expira,v_invitaciones) RETURNING id INTO v_id;
 RETURN jsonb_build_object('ok',true,'paquete_id',v_id,'evento_id',p_evento_id,
 'usuario_id',v_uid,'dispositivo_id',p_dispositivo_id,'creado_at',v_creado,
 'expira_at',v_expira,'participantes',v_filas);
END $$;
REVOKE ALL ON FUNCTION public.offline_descargar(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.offline_descargar(uuid,uuid) TO authenticated;

CREATE FUNCTION public.offline_sincronizar(p_evento_id uuid,p_dispositivo_id uuid,p_paquete_id uuid,
 p_operacion_id uuid,p_token text,p_ingresado_at timestamptz) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid; v_paquete public.offline_paquetes%ROWTYPE;
 v_inv public.invitaciones%ROWTYPE; v_reg public.registros%ROWTYPE;
 v_anterior public.offline_operaciones%ROWTYPE;
 v_hash text; v_acceso uuid; v_ingreso timestamptz; v_resultado jsonb;
BEGIN
 v_uid:=public.offline_autorizar(p_evento_id);
 IF p_operacion_id IS NULL OR p_dispositivo_id IS NULL OR p_token IS NULL
    OR p_token !~ '^[a-fA-F0-9]{64}$' OR p_ingresado_at IS NULL
 THEN RAISE EXCEPTION 'Entrada offline inválida'; END IF;
 SELECT * INTO v_paquete FROM public.offline_paquetes
 WHERE id=p_paquete_id AND evento_id=p_evento_id AND usuario_id=v_uid AND dispositivo_id=p_dispositivo_id
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'El paquete no pertenece a esta cuenta, equipo y evento' USING ERRCODE='42501'; END IF;
 v_hash:=encode(sha256(convert_to(p_token,'UTF8')),'hex');
 SELECT * INTO v_anterior FROM public.offline_operaciones
 WHERE paquete_id=p_paquete_id AND operacion_id=p_operacion_id;
 IF FOUND THEN
  IF v_anterior.token_hash<>v_hash OR v_anterior.ingresado_at<>p_ingresado_at
  THEN RAISE EXCEPTION 'Identificador de operación reutilizado con otros datos'; END IF;
  RETURN v_anterior.resultado;
 END IF;
 IF clock_timestamp()>v_paquete.expira_at+interval '7 days'
    OR p_ingresado_at<v_paquete.creado_at-interval '5 minutes'
    OR p_ingresado_at>v_paquete.expira_at OR p_ingresado_at>clock_timestamp()+interval '5 minutes'
 THEN RETURN jsonb_build_object('ok',false,'estado','fecha_fuera_de_rango'); END IF;
 SELECT * INTO v_inv FROM public.invitaciones WHERE token_hash=v_hash;
 IF NOT FOUND OR NOT(v_inv.id=ANY(v_paquete.invitaciones))
 THEN RETURN jsonb_build_object('ok',false,'estado','qr_fuera_del_paquete'); END IF;
 SELECT * INTO v_reg FROM public.registros WHERE id=v_inv.registro_id AND evento_id=p_evento_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'estado','registro_inexistente'); END IF;
 -- Same lock order as existing online entry: registration, then invitation.
 SELECT * INTO v_inv FROM public.invitaciones WHERE id=v_inv.id FOR UPDATE;
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
  INSERT INTO public.accesos(invitacion_id,operador_id,ingresado_at)
  VALUES(v_inv.id,v_uid,p_ingresado_at) RETURNING id INTO v_acceso;
  v_resultado:=jsonb_build_object('ok',true,'estado','ingreso_registrado',
    'acceso_id',v_acceso,'ingresado_at',p_ingresado_at);
 END IF;
 INSERT INTO public.offline_operaciones(paquete_id,operacion_id,token_hash,ingresado_at,resultado)
 VALUES(p_paquete_id,p_operacion_id,v_hash,p_ingresado_at,v_resultado);
 RETURN v_resultado;
END $$;
REVOKE ALL ON FUNCTION public.offline_sincronizar(uuid,uuid,uuid,uuid,text,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.offline_sincronizar(uuid,uuid,uuid,uuid,text,timestamptz) TO authenticated;
