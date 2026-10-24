BEGIN;
-- Prepared from the read-only catalog; no production data changes.

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
    IF p_foto_path IS NULL OR p_foto_path NOT LIKE p_evento_id::text || '/%'
    OR (p_comprobante_path IS NOT NULL AND p_comprobante_path NOT LIKE p_evento_id::text || '/%')
    THEN RAISE EXCEPTION 'Archivo de otro evento'; END IF;
    IF p_evento_id IS DISTINCT FROM '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN RAISE EXCEPTION 'Operacion exclusiva de RADEVS'; END IF;
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
  WHERE solicitud_id = p_solicitud_id AND evento_id=p_evento_id;

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
    IF p_foto_path IS NULL OR p_foto_path NOT LIKE p_evento_id::text || '/%'
    OR (p_comprobante_path IS NOT NULL AND p_comprobante_path NOT LIKE p_evento_id::text || '/%')
    THEN RAISE EXCEPTION 'Archivo de otro evento'; END IF;
    IF p_evento_id IS DISTINCT FROM '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN RAISE EXCEPTION 'Operacion exclusiva de RADEVS'; END IF;
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
    IF TRUE THEN
      v_limite := LEAST(1500,coalesce(v_maximo,1500),coalesce(p_max_registros,1500));
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
    IF p_foto_path IS NULL OR p_foto_path NOT LIKE p_evento_id::text || '/%'
    OR (p_comprobante_path IS NOT NULL AND p_comprobante_path NOT LIKE p_evento_id::text || '/%')
    THEN RAISE EXCEPTION 'Archivo de otro evento'; END IF;
    IF p_evento_id IS NULL OR p_evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid) THEN RAISE EXCEPTION 'Evento no autorizado'; END IF;
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
 IF v_empleado AND p_evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid THEN
   RAISE EXCEPTION 'Chiapas no admite empleados';
 END IF;
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
    v_limite := least(CASE WHEN p_evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid THEN 500 ELSE 1500 END, coalesce(v_maximo,1500), coalesce(p_max_registros,1500));
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
    IF p_evento_id IS DISTINCT FROM '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN RAISE EXCEPTION 'Operacion exclusiva de RADEVS'; END IF;
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
    IF p_evento_id IS DISTINCT FROM '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN RAISE EXCEPTION 'Operacion exclusiva de RADEVS'; END IF;
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

  IF NEW.evento_id IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid) THEN
    v_maximo := LEAST(coalesce(v_maximo,1500),CASE WHEN NEW.evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid THEN 500 ELSE 1500 END);
  END IF;
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

COMMIT;
