-- REVIEW ONLY. Requires separate explicit production approval.
-- Alternative to the consolidated migration: NEVER apply both routes.
BEGIN;
DO $stage_guard$ BEGIN
IF to_regprocedure('public.consultar_grupo_registro_admin(uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.consultar_grupo_registro_admin(uuid)'))) IS DISTINCT FROM 'ba8405ff156013c5047e079a785bd1da' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.consultar_grupo_registro_admin(uuid)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.consultar_grupo_registro_admin(uuid)'; END IF;
IF to_regprocedure('public.consultar_qr_acceso_evento(text, uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.consultar_qr_acceso_evento(text, uuid)'))) IS DISTINCT FROM 'f08bf7cdab85b1e3e6020a21d95db833' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.consultar_qr_acceso_evento(text, uuid)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.consultar_qr_acceso_evento(text, uuid)'; END IF;
IF to_regprocedure('public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text)'))) IS DISTINCT FROM 'd9d29d0dd97dd4315d6bb89e1cae236d' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_inscripcion(uuid, text, text, text, text, uuid, text, text, text, uuid, text)'; END IF;
IF to_regprocedure('public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer)'))) IS DISTINCT FROM '2bf39bf3243dd41d716378e0c03e70a8' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_registro_prueba_admin(uuid, uuid, text, text, text, text, text, text, text, text, integer)'; END IF;
IF to_regprocedure('public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)'))) IS DISTINCT FROM 'cca17c5b9588046217be3807f87fba66' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_registro_prueba_admin_v2(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)'; END IF;
IF to_regprocedure('public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer)'))) IS DISTINCT FROM 'f9ae24bcb095e58a2d4ed7da8bf9d8a1' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_registro_publico_v2(uuid, uuid, text, text, text, text, text, text, text, text, integer)'; END IF;
IF to_regprocedure('public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)'))) IS DISTINCT FROM 'dd57bf93778f2bd9ed4ed53d06c4a5c7' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.crear_registro_publico_v3(uuid, uuid, text, text, text, text, text, text, text, text, text, integer)'; END IF;
IF to_regprocedure('public.impedir_sobrecupo_evento()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.impedir_sobrecupo_evento()'))) IS DISTINCT FROM 'a38aedde23f7ed6d098d7763d7273bf0' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.impedir_sobrecupo_evento()')) IS DISTINCT FROM NULL THEN RAISE EXCEPTION 'Drift: public.impedir_sobrecupo_evento()'; END IF;
IF to_regprocedure('public.registrar_entrada_qr_evento(text, uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.registrar_entrada_qr_evento(text, uuid)'))) IS DISTINCT FROM 'eb6d3905e76f6782b628533ed959b7ec' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.registrar_entrada_qr_evento(text, uuid)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.registrar_entrada_qr_evento(text, uuid)'; END IF;
IF to_regprocedure('public.crear_perfil_evento_interno(uuid, uuid, uuid, text, text, text)') IS NOT NULL THEN RAISE EXCEPTION 'Already exists: public.crear_perfil_evento_interno(uuid, uuid, uuid, text, text, text)'; END IF;
END; $stage_guard$;
-- Source: sql/security/qr_eventos_propuesta.sql
-- LOCAL ONLY. Based on the checked-in legacy implementation. Not executed.
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

    IF p_evento_id IS NULL OR p_evento_id NOT IN (
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    ) OR NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador AND ue.evento_id = p_evento_id AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa al evento'; END IF;
    -- Solo administrador y acceso activos.
    IF v_operador IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = v_operador
          AND activo = true
          AND rol IN ('administrador', 'acceso')
    ) THEN
        RAISE EXCEPTION 'Operador no autorizado';
    END IF;

    -- Validar token.
    IF p_token IS NULL
       OR length(p_token) <> 64
       OR p_token !~ '^[0-9a-fA-F]{64}$'
    THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'qr_invalido'
        );
    END IF;

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

    SELECT *
    INTO v_registro
    FROM public.registros
    WHERE id = v_invitacion.registro_id AND evento_id = p_evento_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'no_confirmado'
        );
    END IF;

    SELECT MIN(a.ingresado_at)
    INTO v_ingreso
    FROM public.accesos a
    JOIN public.invitaciones i
      ON i.id = a.invitacion_id
    WHERE i.registro_id = v_registro.id;

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

            -- NUEVA PROTECCIÓN:
            -- Exigir pago validado o cortesía.
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

    IF p_evento_id IS NULL OR p_evento_id NOT IN (
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    ) OR NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador AND ue.evento_id = p_evento_id AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa al evento'; END IF;
  IF v_operador IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = v_operador
      AND activo = true
      AND rol IN ('administrador', 'acceso')
  ) THEN
    RAISE EXCEPTION 'Operador no autorizado';
  END IF;

  IF p_token IS NULL
     OR length(p_token) <> 64
     OR p_token !~ '^[0-9a-fA-F]{64}$'
  THEN
    RETURN jsonb_build_object(
      'ok', false,
      'estado', 'qr_invalido'
    );
  END IF;

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

  -- Bloqueo por inscripción para evitar carreras.
  SELECT *
  INTO v_registro
  FROM public.registros
  WHERE id = v_invitacion.registro_id AND evento_id = p_evento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'estado', 'qr_invalido');
  END IF;
  -- Refresh invitation AFTER acquiring the registration lock: a concurrent reissue
  -- must not let a revoked QR enter using a stale pre-lock snapshot.
  SELECT * INTO v_invitacion FROM public.invitaciones
  WHERE id = v_invitacion.id FOR UPDATE;

  IF v_registro.estado IS DISTINCT FROM 'confirmado'
     OR v_invitacion.estado NOT IN ('emitida', 'activa')
  THEN
    RETURN jsonb_build_object(
      'ok', false,
      'estado', 'no_autorizado'
    );
  END IF;

  -- Impedir el ingreso de una inscripción sin
  -- pago validado ni cortesía autorizada.
  IF NOT COALESCE(v_registro.exento_pago, false)
     AND NOT EXISTS (
       SELECT 1
       FROM public.pagos
       WHERE registro_id = v_registro.id
         AND estado = 'validado'
     )
  THEN
    RETURN jsonb_build_object(
      'ok', false,
      'estado', 'sin_pago'
    );
  END IF;

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

REVOKE ALL ON FUNCTION public.consultar_qr_acceso_evento(text,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.registrar_entrada_qr_evento(text,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consultar_qr_acceso_evento(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_qr_evento(text,uuid) TO authenticated;


-- Source: sql/security/perfiles_evento_propuesta.sql
-- Required by the server-side assignment guard. Current production ACL lacks these.
GRANT SELECT, INSERT, UPDATE ON public.usuarios_eventos TO service_role;

CREATE OR REPLACE FUNCTION public.consultar_grupo_registro_admin(p_registro_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_grupo text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.usuarios u WHERE u.id=auth.uid() AND u.activo IS TRUE AND u.rol='administrador'
 ) THEN RAISE EXCEPTION 'No autorizado' USING ERRCODE='42501'; END IF;
 SELECT r.grupo_ruta INTO v_grupo FROM public.registros r
 WHERE r.id=p_registro_id AND EXISTS (
   SELECT 1 FROM public.usuarios_eventos ue
   WHERE ue.usuario_id=auth.uid() AND ue.evento_id=r.evento_id AND ue.activo IS TRUE
 );
 IF NOT FOUND THEN RAISE EXCEPTION 'Inscripción no encontrada' USING ERRCODE='42501'; END IF;
 RETURN v_grupo;
END;
$function$;
REVOKE ALL ON FUNCTION public.consultar_grupo_registro_admin(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.consultar_grupo_registro_admin(uuid) TO authenticated;

-- Auth account is created by the Edge first. Profile + assignment are one DB transaction.
-- On failure, the Edge removes only the newly-created Auth account; no orphan profile.
CREATE FUNCTION public.crear_perfil_evento_interno(
 p_admin_id uuid,p_evento_id uuid,p_usuario_id uuid,p_nombre text,p_nombre_usuario text,p_rol text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
   RAISE EXCEPTION 'Identidad incorrecta' USING ERRCODE='42501';
 END IF;
 IF p_evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid)
 OR NOT EXISTS (
   SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
   WHERE u.id=p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
     AND ue.evento_id=p_evento_id AND ue.activo IS TRUE
 ) THEN RAISE EXCEPTION 'Administrador no autorizado' USING ERRCODE='42501'; END IF;
 IF p_usuario_id IS NULL OR p_evento_id IS NULL OR p_rol IS NULL
 OR p_rol NOT IN ('administrador','validador','recepcion','acceso')
 OR p_nombre IS NULL OR char_length(btrim(p_nombre)) NOT BETWEEN 2 AND 120
 OR p_nombre_usuario IS NULL OR p_nombre_usuario !~ '^[a-z][a-z0-9._-]{2,31}$'
 THEN RAISE EXCEPTION 'Perfil inválido'; END IF;
 INSERT INTO public.usuarios(id,nombre,nombre_usuario,rol,activo)
 VALUES(p_usuario_id,btrim(p_nombre),p_nombre_usuario,p_rol,true);
 INSERT INTO public.usuarios_eventos(usuario_id,evento_id,activo)
 VALUES(p_usuario_id,p_evento_id,true);
 INSERT INTO public.auditoria(usuario_id,accion,entidad,entidad_id,detalles)
 VALUES(p_admin_id,'crear_usuario','usuarios',p_usuario_id,jsonb_build_object('evento_id',p_evento_id,'rol',p_rol));
END;
$function$;
REVOKE ALL ON FUNCTION public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text) TO service_role;

-- Source: sql/security/registro_multievento_propuesta.sql
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


-- Source: sql/security/rls_storage_propuesta.sql
-- LOCAL ONLY. Review existing policies and schema dump; rehearse in disposable DB.
-- Restrictive policies intersect existing permissive policies; they grant no new access.
ALTER TABLE public.registros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accesos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_eventos ENABLE ROW LEVEL SECURITY;
-- Anonymous users access only the dedicated public registration endpoints, never tables.
DO $policies$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('CREATE POLICY evento_privado_anon ON public.%I AS RESTRICTIVE FOR SELECT TO anon USING (false)',t);
  END LOOP;
END;
$policies$;
CREATE POLICY evento_perfil_propio ON public.usuarios AS RESTRICTIVE
FOR SELECT TO authenticated USING (id=(SELECT auth.uid()) AND activo IS TRUE);
CREATE POLICY evento_promotoras_lectura ON public.promotoras AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r WHERE r.promotora_id=promotoras.id)
);
-- All writes use the authorized Edge endpoints or checked SECURITY DEFINER RPCs.
DO $writes$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria'] LOOP
    EXECUTE format('CREATE POLICY evento_solo_backend_insert ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated,anon WITH CHECK(false)',t);
    EXECUTE format('CREATE POLICY evento_solo_backend_update ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated,anon USING(false) WITH CHECK(false)',t);
    EXECUTE format('CREATE POLICY evento_solo_backend_delete ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated,anon USING(false)',t);
  END LOOP;
END;
$writes$;
CREATE POLICY evento_auditoria_propia ON public.auditoria AS RESTRICTIVE
FOR SELECT TO authenticated USING (usuario_id=(SELECT auth.uid()));
CREATE POLICY evento_asignacion_propia ON public.usuarios_eventos AS RESTRICTIVE
FOR SELECT TO authenticated USING (usuario_id = (SELECT auth.uid()) AND activo IS TRUE);
CREATE POLICY evento_registros_lectura ON public.registros AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
    WHERE u.id=(SELECT auth.uid()) AND u.activo IS TRUE AND ue.activo IS TRUE
      AND ue.evento_id=registros.evento_id
      AND u.rol IN ('administrador','validador','recepcion','acceso'))
);
CREATE POLICY evento_pagos_lectura ON public.pagos AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
    JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE r.id=pagos.registro_id AND u.id=(SELECT auth.uid())
      AND u.activo IS TRUE AND ue.activo IS TRUE AND u.rol IN ('administrador','validador'))
);
CREATE POLICY evento_invitaciones_lectura ON public.invitaciones AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r WHERE r.id=invitaciones.registro_id)
);
CREATE POLICY evento_accesos_lectura ON public.accesos AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.invitaciones i WHERE i.id=accesos.invitacion_id)
);
CREATE POLICY evento_comprobantes_lectura ON storage.objects AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  bucket_id <> 'comprobantes-pago' OR EXISTS (
    SELECT 1 FROM public.pagos p JOIN public.registros r ON r.id=p.registro_id
      JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
      JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE p.comprobante_path=storage.objects.name AND u.id=(SELECT auth.uid())
      AND ue.activo IS TRUE AND u.activo IS TRUE AND u.rol IN ('administrador','validador')
  )
);
CREATE POLICY evento_fotos_lectura ON storage.objects AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  bucket_id <> 'fotos-promotoras' OR EXISTS (
    SELECT 1 FROM public.promotoras p JOIN public.registros r ON r.promotora_id=p.id
      JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
      JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE p.foto_path=storage.objects.name AND u.id=(SELECT auth.uid())
      AND ue.activo IS TRUE AND u.activo IS TRUE
      AND u.rol IN ('administrador','validador','recepcion','acceso')
  )
);
CREATE POLICY evento_archivos_anon ON storage.objects AS RESTRICTIVE
FOR SELECT TO anon USING (bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_insert ON storage.objects AS RESTRICTIVE
FOR INSERT TO authenticated,anon WITH CHECK(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_update ON storage.objects AS RESTRICTIVE
FOR UPDATE TO authenticated,anon
USING(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'))
WITH CHECK(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_delete ON storage.objects AS RESTRICTIVE
FOR DELETE TO authenticated,anon USING(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
-- Public bucket URLs bypass RLS. Private status is a prerequisite, not a substitute.
UPDATE storage.buckets SET public=false WHERE id IN ('comprobantes-pago','fotos-promotoras');

COMMIT;
