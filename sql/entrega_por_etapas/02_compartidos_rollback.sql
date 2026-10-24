-- REVIEW ONLY. Requires separate explicit production approval.
-- Alternative to the consolidated migration: NEVER apply both routes.
BEGIN;
DO $stage_guard$ BEGIN
IF to_regprocedure('public.consultar_grupo_registro_admin(uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.consultar_grupo_registro_admin(uuid)'))) IS DISTINCT FROM 'a4a785d99c425830295d4bc84aee456b' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.consultar_grupo_registro_admin(uuid)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.consultar_grupo_registro_admin(uuid)'; END IF;
IF to_regprocedure('public.consultar_qr_acceso_evento(text, uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.consultar_qr_acceso_evento(text, uuid)'))) IS DISTINCT FROM '9074d35dee4c5514f26871b912974b30' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.consultar_qr_acceso_evento(text, uuid)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.consultar_qr_acceso_evento(text, uuid)'; END IF;
IF to_regprocedure('public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text)'))) IS DISTINCT FROM '6548f2b5ddcee0180825593dff7f1327' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text)'; END IF;
IF to_regprocedure('public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer)'))) IS DISTINCT FROM '3bd15e646e98b325c9cd811aeb1025ea' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer)'; END IF;
IF to_regprocedure('public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)'))) IS DISTINCT FROM '6cc3145ef78297cd2147a54ad6462780' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)'; END IF;
IF to_regprocedure('public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer)'))) IS DISTINCT FROM 'af8929df22a403410f70618984d715a2' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer)'; END IF;
IF to_regprocedure('public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)'))) IS DISTINCT FROM 'd6e69ef8e46433f4c716c4f2937c2399' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)'; END IF;
IF to_regprocedure('public.impedir_sobrecupo_evento()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.impedir_sobrecupo_evento()'))) IS DISTINCT FROM '4f98f10af7302e9483b0c1849534d898' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.impedir_sobrecupo_evento()')) IS DISTINCT FROM '{postgres=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.impedir_sobrecupo_evento()'; END IF;
IF to_regprocedure('public.registrar_entrada_qr_evento(text, uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.registrar_entrada_qr_evento(text, uuid)'))) IS DISTINCT FROM '5d72ed6a0c02dc471ba37450f5eabffd' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.registrar_entrada_qr_evento(text, uuid)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.registrar_entrada_qr_evento(text, uuid)'; END IF;
IF to_regprocedure('public.crear_perfil_evento_interno(uuid, uuid, uuid, text, text, text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_perfil_evento_interno(uuid, uuid, uuid, text, text, text)'))) IS DISTINCT FROM 'e473dbdaaa5acdaf065c43dbf633e064' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_perfil_evento_interno(uuid, uuid, uuid, text, text, text)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_perfil_evento_interno(uuid, uuid, uuid, text, text, text)'; END IF;

END; $stage_guard$;
CREATE OR REPLACE FUNCTION public.consultar_grupo_registro_admin(p_registro_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_grupo text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = auth.uid() AND activo IS TRUE AND rol = 'administrador'
 ) THEN
    RAISE EXCEPTION 'No autorizado' USING ERRCODE = '42501';
 END IF;
 SELECT grupo_ruta INTO v_grupo FROM public.registros WHERE id = p_registro_id;
 RETURN v_grupo;
END;
$function$
;
REVOKE ALL ON FUNCTION public.consultar_grupo_registro_admin(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.consultar_grupo_registro_admin(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.consultar_qr_acceso_evento(p_token text, p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_operador uuid := auth.uid();
    v_invitacion public.invitaciones%ROWTYPE;
    v_registro public.registros%ROWTYPE;
    v_ingreso timestamptz;
BEGIN
    -- 1. Operador autenticado, activo y con rol permitido.
    IF v_operador IS NULL
       OR NOT EXISTS (
           SELECT 1
           FROM public.usuarios u
           WHERE u.id = v_operador
             AND u.activo = true
             AND u.rol IN ('administrador', 'acceso')
       )
    THEN
        RAISE EXCEPTION 'Operador no autorizado';
    END IF;

    -- 2. Autorizacion para el evento solicitado.
    IF p_evento_id IS NULL
       OR NOT EXISTS (
           SELECT 1
           FROM public.usuarios_eventos ue
           WHERE ue.usuario_id = v_operador
             AND ue.evento_id = p_evento_id
             AND ue.activo = true
       )
    THEN
        RAISE EXCEPTION 'Operador sin permiso para este evento';
    END IF;

    -- 3. Validar formato del token.
    IF p_token IS NULL
       OR length(p_token) <> 64
       OR p_token !~ '^[0-9a-fA-F]{64}$'
    THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'qr_invalido'
        );
    END IF;

    -- 4. Buscar invitacion por hash.
    SELECT *
    INTO v_invitacion
    FROM public.invitaciones
    WHERE token_hash = encode(
        sha256(convert_to(p_token, 'UTF8')),
        'hex'
    );

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'qr_invalido'
        );
    END IF;

    -- 5. Comprobar el evento REAL del registro.
    SELECT *
    INTO v_registro
    FROM public.registros
    WHERE id = v_invitacion.registro_id;

    IF NOT FOUND
       OR v_registro.evento_id IS DISTINCT FROM p_evento_id
    THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'qr_invalido'
        );
    END IF;

    -- 6. Revisar ingreso anterior.
    SELECT MIN(a.ingresado_at)
    INTO v_ingreso
    FROM public.accesos a
    JOIN public.invitaciones i
      ON i.id = a.invitacion_id
    WHERE i.registro_id = v_registro.id;

    -- 7. Conservar comprobaciones existentes.
    RETURN jsonb_build_object(
        'ok', true,
        'invitacion_id', v_invitacion.id,
        'registro_id', v_registro.id,
        'folio', v_registro.folio,
        'registro_estado', v_registro.estado,
        'invitacion_estado', v_invitacion.estado,
        'ingresado_at', v_ingreso,
        'estado',
        CASE
            WHEN v_ingreso IS NOT NULL
                THEN 'ya_ingreso'

            WHEN v_registro.estado IS DISTINCT FROM 'confirmado'
                THEN 'no_confirmado'

            WHEN v_invitacion.estado NOT IN ('emitida', 'activa')
                THEN 'revocada'

            WHEN NOT COALESCE(v_registro.exento_pago, false)
                 AND NOT EXISTS (
                     SELECT 1
                     FROM public.pagos p
                     WHERE p.registro_id = v_registro.id
                       AND p.estado = 'validado'
                 )
                THEN 'sin_pago'

            ELSE 'autorizable'
        END
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.consultar_qr_acceso_evento(text, uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.consultar_qr_acceso_evento(text, uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.crear_inscripcion(p_evento_id uuid, p_nombres text, p_apellidos text, p_telefono text, p_estado text, p_asesor_id uuid, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_solicitud_id uuid, p_privacidad_version text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_evento public.eventos%ROWTYPE;
  v_promotora_id uuid;
  v_registro_id uuid;
BEGIN
  -- Esta función solo debe ejecutarse desde un
  -- contexto privilegiado del servidor.
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Operación no autorizada';
  END IF;

  SELECT *
  INTO v_evento
  FROM public.eventos
  WHERE id = p_evento_id
    AND estado = 'activo';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El evento no está disponible';
  END IF;

  IF length(trim(coalesce(p_nombres, ''))) < 2
     OR length(trim(coalesce(p_apellidos, ''))) < 2
     OR coalesce(p_telefono, '') !~ '^[0-9]{10}$'
     OR length(trim(coalesce(p_estado, ''))) < 2
     OR p_solicitud_id IS NULL
     OR length(trim(coalesce(p_foto_path, ''))) = 0
     OR length(trim(coalesce(p_comprobante_path, ''))) = 0
     OR length(trim(coalesce(p_cuenta_destino, ''))) = 0
     OR length(trim(coalesce(p_privacidad_version, ''))) = 0
  THEN
    RAISE EXCEPTION 'Datos de inscripción inválidos';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.asesores
    WHERE id = p_asesor_id
      AND activo = true
  ) THEN
    RAISE EXCEPTION 'Asesor no válido';
  END IF;

  -- Evitar procesar dos veces la misma solicitud.
  SELECT id
  INTO v_registro_id
  FROM public.registros
  WHERE solicitud_id = p_solicitud_id;

  IF FOUND THEN
    RETURN v_registro_id;
  END IF;

  INSERT INTO public.promotoras (
    nombres,
    apellidos,
    telefono_whatsapp,
    estado_residencia,
    foto_path
  )
  VALUES (
    trim(p_nombres),
    trim(p_apellidos),
    p_telefono,
    trim(p_estado),
    p_foto_path
  )
  RETURNING id INTO v_promotora_id;

  INSERT INTO public.registros (
    evento_id,
    promotora_id,
    asesor_id,
    estado,
    solicitud_id,
    privacidad_aceptada_at,
    privacidad_version
  )
  VALUES (
    p_evento_id,
    v_promotora_id,
    p_asesor_id,
    'pendiente',
    p_solicitud_id,
    now(),
    p_privacidad_version
  )
  RETURNING id INTO v_registro_id;

  INSERT INTO public.pagos (
    registro_id,
    importe,
    comprobante_path,
    cuenta_destino,
    estado
  )
  VALUES (
    v_registro_id,
    v_evento.cuota_fija,
    p_comprobante_path,
    p_cuenta_destino,
    'pendiente'
  );

  RETURN v_registro_id;
END;
$function$
;
REVOKE ALL ON FUNCTION public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text) TO service_role;
CREATE OR REPLACE FUNCTION public.crear_registro_prueba_admin(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_resultado jsonb;
  v_registro_id uuid;
BEGIN
  IF p_nombres IS NULL OR p_nombres !~* '^PRUEBA([ -]|$)' THEN
    RAISE EXCEPTION 'El nombre debe comenzar con PRUEBA';
  END IF;
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Solo el backend autorizado puede registrar pruebas';
  END IF;

  -- La marca se transmite por sesión SQL INTERNA, no por petición pública.
  -- set_config(..., true) la limita a esta transacción de la llamada RPC.
  PERFORM set_config('app.modo_prueba_admin', 'si', true);
  v_resultado := public.crear_registro_publico_v2(
    p_evento_id, p_asesor_id, p_nombres, p_apellidos,
    p_estado_residencia, p_whatsapp, p_tipo_participante,
    p_foto_path, p_comprobante_path, p_cuenta_destino, NULL
  );
  PERFORM set_config('app.modo_prueba_admin', '', true);

  IF coalesce((v_resultado ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_resultado;
  END IF;
  v_registro_id := (v_resultado ->> 'registro_id')::uuid;
  IF NOT EXISTS (
    SELECT 1 FROM public.registros
    WHERE id = v_registro_id AND evento_id = p_evento_id AND es_prueba IS TRUE
  ) THEN
    RAISE EXCEPTION 'La inscripción de prueba no quedó identificada correctamente';
  END IF;
  RETURN v_resultado || jsonb_build_object('es_prueba', true);
END;
$function$
;
REVOKE ALL ON FUNCTION public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer) TO service_role;
CREATE OR REPLACE FUNCTION public.crear_registro_prueba_admin_v2(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_grupo_ruta text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_resultado jsonb;
 v_registro_id uuid;
BEGIN
 IF coalesce(auth.role(),'') <> 'service_role' THEN
   RAISE EXCEPTION 'Solo el backend autorizado puede registrar pruebas';
 END IF;
 IF p_nombres IS NULL OR p_nombres !~* '^PRUEBA([ -]|$)' THEN
   RAISE EXCEPTION 'El nombre debe comenzar con PRUEBA';
 END IF;
 PERFORM set_config('app.modo_prueba_admin','si',true);
 v_resultado := public.crear_registro_publico_v3(
   p_evento_id, p_asesor_id, p_nombres, p_apellidos,
   p_estado_residencia, p_whatsapp, p_tipo_participante,
   p_grupo_ruta, p_foto_path, p_comprobante_path,
   p_cuenta_destino, NULL
 );
 PERFORM set_config('app.modo_prueba_admin','',true);
 IF coalesce((v_resultado->>'ok')::boolean,false) IS NOT TRUE THEN
   RETURN v_resultado;
 END IF;
 v_registro_id := (v_resultado->>'registro_id')::uuid;
 IF NOT EXISTS (
   SELECT 1 FROM public.registros WHERE id = v_registro_id
    AND evento_id = p_evento_id AND es_prueba IS TRUE
 ) THEN
   RAISE EXCEPTION 'El registro de prueba no quedó identificado';
 END IF;
 RETURN v_resultado || jsonb_build_object('es_prueba',true);
END;
$function$
;
REVOKE ALL ON FUNCTION public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer) TO service_role;
CREATE OR REPLACE FUNCTION public.crear_registro_publico_v2(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_promotora_id uuid;
  v_registro_id uuid;
  v_folio text;
  v_total bigint;
  v_maximo integer;
  v_limite integer;
  v_es_prueba boolean := coalesce(current_setting('app.modo_prueba_admin', true), '') = 'si';
BEGIN
  IF p_evento_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.eventos WHERE id = p_evento_id
  ) THEN
    RAISE EXCEPTION 'El evento no está disponible';
  END IF;
  IF p_nombres IS NULL OR length(btrim(p_nombres)) < 2 OR length(btrim(p_nombres)) > 100
     OR p_apellidos IS NULL OR length(btrim(p_apellidos)) < 2 OR length(btrim(p_apellidos)) > 100
     OR p_estado_residencia IS NULL OR length(btrim(p_estado_residencia)) < 2
     OR p_whatsapp IS NULL OR p_whatsapp !~ '^[0-9]{10}$'
     OR p_tipo_participante IS NULL OR p_tipo_participante NOT IN ('vendedora', 'promotora')
     OR p_foto_path IS NULL OR length(btrim(p_foto_path)) < 5
     OR p_comprobante_path IS NULL OR length(btrim(p_comprobante_path)) < 5
     OR p_cuenta_destino IS NULL OR length(btrim(p_cuenta_destino)) < 5
  THEN
    RAISE EXCEPTION 'Faltan datos obligatorios o contienen valores incorrectos';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.asesores WHERE id = p_asesor_id AND activo IS TRUE
  ) THEN
    RAISE EXCEPTION 'Selecciona un asesor válido';
  END IF;
  IF v_es_prueba AND coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'No autorizado para registrar una prueba';
  END IF;
  IF p_max_registros IS NOT NULL AND p_max_registros < 1 THEN
    RAISE EXCEPTION 'MAX_REGISTROS_EVENTO debe ser positivo';
  END IF;

  -- Protege DUPLICADOS y CUPO de dos altas simultáneas.
  PERFORM pg_advisory_xact_lock(
    hashtextextended('evento-anual-' || p_evento_id::text, 0)
  );

  -- Inscripciones de prueba y reales no compiten por WhatsApp.
  IF EXISTS (
    SELECT 1 FROM public.registros r
    JOIN public.promotoras p ON p.id = r.promotora_id
    WHERE r.evento_id = p_evento_id
      AND p.telefono_whatsapp = p_whatsapp
      AND coalesce(r.es_prueba, false) = v_es_prueba
      AND coalesce(r.estado, 'pendiente') NOT IN ('cancelado', 'rechazado')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'codigo', 'DUPLICADO',
      'mensaje', 'Ya existe una inscripción con ese WhatsApp para este evento.');
  END IF;

  IF NOT v_es_prueba THEN
    SELECT cupo_maximo INTO v_maximo
    FROM public.configuracion_cupo_evento WHERE evento_id = p_evento_id;
    -- El cupo configurado prevalece; un límite anterior más bajo es adicional.
    -- Otros eventos sin configuración conservan el comportamiento original.
    IF v_maximo IS NOT NULL OR p_max_registros IS NOT NULL THEN
      v_limite := LEAST(coalesce(v_maximo, p_max_registros), coalesce(p_max_registros, v_maximo));
      SELECT count(*) INTO v_total
      FROM public.registros
      WHERE evento_id = p_evento_id
        AND NOT coalesce(es_prueba, false)
        AND coalesce(estado, 'pendiente') NOT IN ('cancelado', 'rechazado');
      IF v_total >= v_limite THEN
        RETURN jsonb_build_object('ok', false, 'codigo', 'SIN_CUPO',
          'mensaje', 'El evento ya alcanzó el cupo disponible.');
      END IF;
    END IF;
  END IF;

  INSERT INTO public.promotoras(
    nombres, apellidos, telefono_whatsapp, estado_residencia,
    tipo_participante, foto_path
  ) VALUES (
    btrim(p_nombres), btrim(p_apellidos), p_whatsapp,
    btrim(p_estado_residencia), p_tipo_participante, p_foto_path
  ) RETURNING id INTO v_promotora_id;

  v_folio := 'EA26-' || upper(replace(gen_random_uuid()::text, '-', ''));
  INSERT INTO public.registros(
    evento_id, promotora_id, asesor_id, estado, exento_pago, folio,
    aviso_privacidad_aceptado_at, es_prueba
  ) VALUES (
    p_evento_id, v_promotora_id, p_asesor_id,
    'pendiente', false, v_folio, now(), v_es_prueba
  ) RETURNING id INTO v_registro_id;

  INSERT INTO public.pagos(registro_id, importe, comprobante_path, cuenta_destino, estado)
  VALUES (v_registro_id, 300.00, p_comprobante_path, p_cuenta_destino, 'pendiente');

  RETURN jsonb_build_object(
    'ok', true, 'folio', v_folio, 'registro_id', v_registro_id,
    'estado', 'pendiente', 'es_prueba', v_es_prueba
  );
END;
$function$
;
REVOKE ALL ON FUNCTION public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer) TO service_role;
CREATE OR REPLACE FUNCTION public.crear_registro_publico_v3(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_grupo_ruta text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_promotora_id uuid;
 v_registro_id uuid;
 v_folio text;
 v_total bigint;
 v_maximo integer;
 v_limite integer;
 v_nombre_asesor text;
 v_empleado boolean;
 v_sin_pago boolean;
 v_grupo text;
 v_es_prueba boolean := coalesce(current_setting('app.modo_prueba_admin',true),'') = 'si';
BEGIN
 -- Sólo las Edge Functions con service_role pueden guardar inscripciones.
 IF coalesce(auth.role(),'') <> 'service_role' THEN
   RAISE EXCEPTION 'Registro no autorizado';
 END IF;
 IF p_evento_id IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.eventos WHERE id = p_evento_id
 ) THEN
   RAISE EXCEPTION 'El evento no está disponible';
 END IF;
 IF p_nombres IS NULL OR char_length(btrim(p_nombres)) NOT BETWEEN 2 AND 100
 OR p_apellidos IS NULL OR char_length(btrim(p_apellidos)) NOT BETWEEN 2 AND 100
 OR p_estado_residencia IS NULL OR char_length(btrim(p_estado_residencia)) < 2
 OR p_whatsapp IS NULL OR p_whatsapp !~ '^[0-9]{10}$'
 OR p_tipo_participante IS NULL OR p_tipo_participante NOT IN ('vendedora','promotora')
 OR p_foto_path IS NULL OR char_length(btrim(p_foto_path)) < 5 THEN
    RAISE EXCEPTION 'Datos obligatorios inválidos';
 END IF;

 -- EMPLEADO es una designación exclusiva del asesor activo; no es un flag cliente.
 SELECT nombre INTO v_nombre_asesor
 FROM public.asesores WHERE id = p_asesor_id AND activo IS TRUE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona un asesor válido'; END IF;
 v_empleado := upper(btrim(v_nombre_asesor)) = 'EMPLEADO';
 v_sin_pago := p_tipo_participante = 'promotora';
 IF v_empleado AND NOT v_sin_pago THEN
    RAISE EXCEPTION 'EMPLEADO no debe registrar pagos';
 END IF;
 v_grupo := CASE WHEN v_empleado THEN NULL ELSE nullif(btrim(p_grupo_ruta),'') END;
 IF NOT v_empleado AND (v_grupo IS NULL OR char_length(v_grupo) NOT BETWEEN 2 AND 60) THEN
    RAISE EXCEPTION 'El grupo de ruta es obligatorio (2 a 60 caracteres)';
 END IF;

 -- VENDEDORA: cuenta y comprobante. PROMOTORA/EMPLEADO: sin pago,
 -- sin comprobante y sin acceso QR hasta una cortesía aprobada.
 IF NOT v_sin_pago AND (
   p_comprobante_path IS NULL OR char_length(btrim(p_comprobante_path)) < 5
   OR p_cuenta_destino IS NULL OR char_length(btrim(p_cuenta_destino)) < 5
 ) THEN
   RAISE EXCEPTION 'La vendedora debe adjuntar comprobante y cuenta';
 END IF;
 IF v_sin_pago AND (nullif(btrim(p_comprobante_path),'') IS NOT NULL
                   OR nullif(btrim(p_cuenta_destino),'') IS NOT NULL) THEN
   RAISE EXCEPTION 'La cortesía no admite comprobante ni cuenta';
 END IF;
 IF p_max_registros IS NOT NULL AND p_max_registros < 1 THEN
   RAISE EXCEPTION 'El límite debe ser positivo';
 END IF;

 -- Mismo bloqueo que la v2: evitar duplicados y sobrecupo simultáneo.
 PERFORM pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended('evento-anual-' || p_evento_id::text, 0)
 );
 IF EXISTS (
    SELECT 1 FROM public.registros r
    JOIN public.promotoras p ON p.id = r.promotora_id
    WHERE r.evento_id = p_evento_id
      AND p.telefono_whatsapp = p_whatsapp
      AND coalesce(r.es_prueba,false) = v_es_prueba
      AND coalesce(r.estado,'pendiente') NOT IN ('cancelado','rechazado')
 ) THEN
    RETURN jsonb_build_object('ok',false,'codigo','DUPLICADO',
      'mensaje','Ya existe una inscripción con ese WhatsApp para este evento.');
 END IF;

 IF NOT v_es_prueba THEN
    SELECT cupo_maximo INTO v_maximo FROM public.configuracion_cupo_evento
    WHERE evento_id = p_evento_id;
    -- Bajo ninguna circunstancia pasar de 1500; mantener límites menores.
    v_limite := least(1500, coalesce(v_maximo,1500), coalesce(p_max_registros,1500));
    SELECT count(*) INTO v_total FROM public.registros
    WHERE evento_id = p_evento_id AND NOT coalesce(es_prueba,false)
      AND coalesce(estado,'pendiente') NOT IN ('cancelado','rechazado');
    IF v_total >= v_limite THEN
      RETURN jsonb_build_object('ok',false,'codigo','SIN_CUPO',
        'mensaje','El evento ya alcanzó el cupo disponible.');
    END IF;
 END IF;

 INSERT INTO public.promotoras (
   nombres, apellidos, telefono_whatsapp, estado_residencia,
   tipo_participante, foto_path
 ) VALUES (
   btrim(p_nombres), btrim(p_apellidos), p_whatsapp,
   btrim(p_estado_residencia), p_tipo_participante, p_foto_path
 ) RETURNING id INTO v_promotora_id;

 v_folio := 'EA26-' || upper(replace(gen_random_uuid()::text,'-',''));
 INSERT INTO public.registros (
   evento_id, promotora_id, asesor_id, estado, exento_pago,
   folio, aviso_privacidad_aceptado_at, es_prueba, grupo_ruta
 ) VALUES (
   p_evento_id, v_promotora_id, p_asesor_id,
   'pendiente', FALSE, v_folio, now(), v_es_prueba, v_grupo
 ) RETURNING id INTO v_registro_id;

 -- No crear un pago ficticio de $300 para quien tendrá cortesía pendiente.
 IF NOT v_sin_pago THEN
   INSERT INTO public.pagos(registro_id,importe,comprobante_path,cuenta_destino,estado)
   VALUES(v_registro_id,300.00,p_comprobante_path,p_cuenta_destino,'pendiente');
 END IF;
 RETURN jsonb_build_object('ok',true,'folio',v_folio,
   'registro_id',v_registro_id,'estado','pendiente',
   'cortesia_pendiente',v_sin_pago,'es_prueba',v_es_prueba);
END;
$function$
;
REVOKE ALL ON FUNCTION public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer) TO service_role;
CREATE OR REPLACE FUNCTION public.impedir_sobrecupo_evento()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_maximo integer;
  v_ocupados bigint;
  v_contaba_antes boolean;
  v_contara_despues boolean;
  v_intento_marcar_prueba boolean := false;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_intento_marcar_prueba := NEW.es_prueba IS TRUE;
  ELSE
    v_intento_marcar_prueba := NEW.es_prueba IS TRUE AND OLD.es_prueba IS DISTINCT FROM NEW.es_prueba;
  END IF;

  -- Los registros de prueba solo pueden crearse/reclasificarse mediante
  -- el backend con service_role; nadie puede marcar como prueba un alta pública.
  IF v_intento_marcar_prueba AND coalesce(auth.role(), '') <> 'service_role'
    AND session_user <> 'postgres' THEN
    RAISE EXCEPTION 'Solo el backend autorizado puede crear registros de prueba';
  END IF;

  v_contara_despues := NOT coalesce(NEW.es_prueba, false)
    AND coalesce(NEW.estado, 'pendiente') NOT IN ('cancelado', 'rechazado');

  IF TG_OP = 'UPDATE' THEN
    v_contaba_antes := NOT coalesce(OLD.es_prueba, false)
      AND coalesce(OLD.estado, 'pendiente') NOT IN ('cancelado', 'rechazado')
      AND OLD.evento_id IS NOT DISTINCT FROM NEW.evento_id;
  ELSE
    v_contaba_antes := false;
  END IF;

  -- Solo comprobamos cupo cuando el registro COMIENZA a ocupar un lugar.
  IF NOT v_contara_despues OR v_contaba_antes THEN
    RETURN NEW;
  END IF;

  -- MISMA llave que el alta transaccional v2.
  PERFORM pg_advisory_xact_lock(
    hashtextextended('evento-anual-' || NEW.evento_id::text, 0)
  );

  SELECT cupo_maximo INTO v_maximo
  FROM public.configuracion_cupo_evento
  WHERE evento_id = NEW.evento_id;

  IF v_maximo IS NULL THEN
    RETURN NEW; -- No imponemos límites a otros eventos sin configurar.
  END IF;

  SELECT count(*) INTO v_ocupados
  FROM public.registros r
  WHERE r.evento_id = NEW.evento_id
    AND r.id IS DISTINCT FROM NEW.id
    AND NOT coalesce(r.es_prueba, false)
    AND coalesce(r.estado, 'pendiente') NOT IN ('cancelado', 'rechazado');

  IF v_ocupados >= v_maximo THEN
    RAISE EXCEPTION 'CUPO_COMPLETO: el evento alcanzó su límite de % personas', v_maximo
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION public.impedir_sobrecupo_evento() FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.registrar_entrada_qr_evento(p_token text, p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_operador uuid := auth.uid();
    v_invitacion public.invitaciones%ROWTYPE;
    v_registro public.registros%ROWTYPE;
    v_ingreso timestamptz;
    v_acceso_id uuid;
BEGIN
    -- 1. Validar operador.
    IF v_operador IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios u
        WHERE u.id = v_operador
          AND u.activo = true
          AND u.rol IN ('administrador', 'acceso')
    ) THEN
        RAISE EXCEPTION 'Operador no autorizado';
    END IF;

    -- 2. Exigir permiso para el evento.
    IF p_evento_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador
          AND ue.evento_id = p_evento_id
          AND ue.activo = true
    ) THEN
        RAISE EXCEPTION 'Operador sin permiso para este evento';
    END IF;

    -- 3. Validar token.
    IF p_token IS NULL
       OR length(p_token) <> 64
       OR p_token !~ '^[0-9a-fA-F]{64}$'
    THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'qr_invalido'
        );
    END IF;

    -- 4. Localizar invitación.
    SELECT *
    INTO v_invitacion
    FROM public.invitaciones
    WHERE token_hash = encode(
        sha256(convert_to(p_token, 'UTF8')),
        'hex'
    );

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'qr_invalido'
        );
    END IF;

    -- 5. Bloquear el registro durante la operación.
    SELECT *
    INTO v_registro
    FROM public.registros
    WHERE id = v_invitacion.registro_id
    FOR UPDATE;

    IF NOT FOUND
       OR v_registro.evento_id IS DISTINCT FROM p_evento_id
    THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'qr_invalido'
        );
    END IF;

    -- 6. Confirmar inscripción e invitación.
    IF v_registro.estado IS DISTINCT FROM 'confirmado'
       OR v_invitacion.estado NOT IN ('emitida', 'activa')
    THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'no_autorizado'
        );
    END IF;

    -- 7. Exigir pago validado o cortesía autorizada.
    IF NOT COALESCE(v_registro.exento_pago, false)
       AND NOT EXISTS (
           SELECT 1
           FROM public.pagos p
           WHERE p.registro_id = v_registro.id
             AND p.estado = 'validado'
       )
    THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'sin_pago'
        );
    END IF;

    -- 8. Evitar una segunda entrada.
    SELECT MIN(a.ingresado_at)
    INTO v_ingreso
    FROM public.accesos a
    JOIN public.invitaciones i
      ON i.id = a.invitacion_id
    WHERE i.registro_id = v_registro.id;

    IF v_ingreso IS NOT NULL THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'ya_ingreso',
            'ingresado_at', v_ingreso
        );
    END IF;

    -- 9. Registrar entrada.
    INSERT INTO public.accesos (
        id,
        invitacion_id,
        operador_id,
        ingresado_at
    )
    VALUES (
        gen_random_uuid(),
        v_invitacion.id,
        v_operador,
        now()
    )
    RETURNING id, ingresado_at
    INTO v_acceso_id, v_ingreso;

    RETURN jsonb_build_object(
        'ok', true,
        'estado', 'ingreso_registrado',
        'acceso_id', v_acceso_id,
        'registro_id', v_registro.id,
        'ingresado_at', v_ingreso
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.registrar_entrada_qr_evento(text, uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_qr_evento(text, uuid) TO authenticated;
DROP FUNCTION public.crear_perfil_evento_interno(uuid, uuid, uuid, text, text, text);
-- LOCAL ONLY. Roll back only the policies introduced by rls_storage_propuesta.sql.
-- Restore prior RLS flags, bucket visibility and function definitions/ACL from
-- the approved pre-deployment snapshot; never guess a production prior state.
DROP POLICY IF EXISTS evento_asignacion_propia ON public.usuarios_eventos;
DROP POLICY IF EXISTS evento_registros_lectura ON public.registros;
DROP POLICY IF EXISTS evento_pagos_lectura ON public.pagos;
DROP POLICY IF EXISTS evento_invitaciones_lectura ON public.invitaciones;
DROP POLICY IF EXISTS evento_accesos_lectura ON public.accesos;
DROP POLICY IF EXISTS evento_comprobantes_lectura ON storage.objects;
DROP POLICY IF EXISTS evento_fotos_lectura ON storage.objects;
DROP POLICY IF EXISTS evento_archivos_anon ON storage.objects;
DROP POLICY IF EXISTS evento_auditoria_propia ON public.auditoria;
DROP POLICY IF EXISTS evento_archivos_insert ON storage.objects;
DROP POLICY IF EXISTS evento_archivos_update ON storage.objects;
DROP POLICY IF EXISTS evento_archivos_delete ON storage.objects;
DROP POLICY IF EXISTS evento_perfil_propio ON public.usuarios;
DROP POLICY IF EXISTS evento_promotoras_lectura ON public.promotoras;
DO $policies$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS evento_privado_anon ON public.%I',t);
    EXECUTE format('DROP POLICY IF EXISTS evento_solo_backend_insert ON public.%I',t);
    EXECUTE format('DROP POLICY IF EXISTS evento_solo_backend_update ON public.%I',t);
    EXECUTE format('DROP POLICY IF EXISTS evento_solo_backend_delete ON public.%I',t);
  END LOOP;
END;
$policies$;

ALTER TABLE public."accesos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."accesos" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."asesores" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."asesores" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."auditoria" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."auditoria" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."configuracion_cupo_evento" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."configuracion_cupo_evento" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."eventos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."eventos" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."invitaciones" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."invitaciones" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."limites_inicio_sesion" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."limites_inicio_sesion" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."limites_registro" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."limites_registro" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."pagos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."pagos" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."promotoras" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."promotoras" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."registros" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."registros" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."usuarios" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."usuarios" NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public."usuarios_eventos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."usuarios_eventos" NO FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.usuarios_eventos FROM service_role;
GRANT TRUNCATE,REFERENCES,TRIGGER,MAINTAIN ON public.usuarios_eventos TO service_role;
UPDATE storage.buckets SET public=false WHERE id='fotos-promotoras';
UPDATE storage.buckets SET public=false WHERE id='comprobantes-pago';
COMMIT;
