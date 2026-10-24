-- Exact structural rollback to read-only catalog 2026-10-24. No user data is deleted.
BEGIN;
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

CREATE OR REPLACE FUNCTION public.autorizar_cortesia_admin(p_registro_id uuid, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro public.registros%ROWTYPE;
    v_invitacion jsonb;
BEGIN
    -- Verificar administrador activo.
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Administrador no autorizado';
    END IF;

    -- Bloquear inscripción durante la operación.
    SELECT *
    INTO v_registro
    FROM public.registros
    WHERE id = p_registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inscripción inexistente';
    END IF;

    -- CORRECCIÓN:
    -- No otorgar cortesías a inscripciones
    -- canceladas ni rechazadas.
    IF v_registro.estado IN ('cancelado', 'rechazado') THEN
        RAISE EXCEPTION
            'No se pueden autorizar cortesías de inscripciones canceladas o rechazadas';
    END IF;

    -- Evitar convertir un pago validado en cortesía.
    IF EXISTS (
        SELECT 1
        FROM public.pagos
        WHERE registro_id = p_registro_id
          AND estado = 'validado'
    ) THEN
        RAISE EXCEPTION
            'Esta inscripción ya tiene un pago validado';
    END IF;

    -- Autorizar cortesía y confirmar inscripción.
    UPDATE public.registros
    SET exento_pago = TRUE,
        estado = 'confirmado'
    WHERE id = p_registro_id;

    -- Conservar registro de auditoría.
    INSERT INTO public.auditoria (
        usuario_id,
        accion,
        entidad,
        entidad_id,
        detalles
    )
    VALUES (
        p_admin_id,
        'autorizar_cortesia',
        'registros',
        p_registro_id,
        jsonb_build_object(
            'exento_pago_anterior',
            v_registro.exento_pago,
            'estado_anterior',
            v_registro.estado
        )
    );

    -- Conservar emisión de invitación.
    v_invitacion :=
        public.emitir_invitacion_admin_interna(
            p_registro_id,
            p_admin_id,
            FALSE
        );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'registro_id', p_registro_id,
        'invitacion', v_invitacion
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.autorizar_cortesia_admin(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.autorizar_cortesia_admin(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.bandejas_admin_paginadas(p_tipo text, p_pagina integer, p_busqueda text, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_pagina integer := LEAST(GREATEST(COALESCE(p_pagina, 1), 1), 10000);
    v_limite integer := 20;
    v_offset integer;
    v_busqueda text := lower(left(btrim(COALESCE(p_busqueda, '')), 100));
    v_total bigint := 0;
    v_filas jsonb := '[]'::jsonb;
BEGIN
    -- Defensa en profundidad: el UUID debe venir del JWT verificado en Edge.
    -- La funcion NO se concede a anon ni authenticated, solo a service_role.
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Administrador no autorizado';
    END IF;

    IF p_tipo IS NULL OR p_tipo NOT IN ('pagos', 'invitaciones') THEN
        RAISE EXCEPTION 'Tipo de bandeja invalido';
    END IF;

    v_offset := (v_pagina - 1) * v_limite;

    IF p_tipo = 'pagos' THEN
        -- Se conservan los estados de la bandeja original: pendiente/revision.
        WITH filtrados AS MATERIALIZED (
            SELECT
                r.id AS registro_id,
                COALESCE(NULLIF(r.folio, ''), '—') AS folio,
                COALESCE(
                    NULLIF(concat_ws(' ', NULLIF(btrim(m.nombres), ''), NULLIF(btrim(m.apellidos), '')), ''),
                    'Sin nombre'
                ) AS nombre,
                COALESCE(m.telefono_whatsapp, '') AS telefono,
                COALESCE(a.nombre, '') AS asesor,
                r.estado AS registro_estado,
                r.exento_pago,
                p.id AS pago_id,
                p.estado AS pago_estado,
                p.importe,
                p.referencia,
                p.created_at AS fecha,
                p.created_at AS orden_fecha
            FROM public.pagos p
            JOIN public.registros r ON r.id = p.registro_id
            LEFT JOIN public.promotoras m ON m.id = r.promotora_id
            LEFT JOIN public.asesores a ON a.id = r.asesor_id
            WHERE p.estado IN ('pendiente', 'revision')
              AND (
                  v_busqueda = '' OR strpos(
                      lower(concat_ws(' ', m.nombres, m.apellidos,
                                      r.folio, m.telefono_whatsapp, a.nombre)),
                      v_busqueda
                  ) > 0
              )
        ),
        pagina AS (
            SELECT * FROM filtrados
            ORDER BY orden_fecha DESC NULLS LAST, pago_id DESC
            LIMIT v_limite OFFSET v_offset
        )
        SELECT
            (SELECT count(*) FROM filtrados),
            (SELECT COALESCE(
                jsonb_agg(to_jsonb(pg) - 'orden_fecha'
                          ORDER BY pg.orden_fecha DESC NULLS LAST, pg.pago_id DESC),
                '[]'::jsonb
            ) FROM pagina pg)
        INTO v_total, v_filas;

    ELSE
        -- Se conservan TODOS los registros en la bandeja de invitaciones,
        -- incluidos los que aun no tienen invitacion.
        WITH filtrados AS MATERIALIZED (
            SELECT
                r.id AS registro_id,
                COALESCE(NULLIF(r.folio, ''), '—') AS folio,
                COALESCE(
                    NULLIF(concat_ws(' ', NULLIF(btrim(m.nombres), ''), NULLIF(btrim(m.apellidos), '')), ''),
                    'Sin nombre'
                ) AS nombre,
                COALESCE(m.telefono_whatsapp, '') AS telefono,
                COALESCE(a.nombre, '') AS asesor,
                r.estado AS registro_estado,
                r.exento_pago,
                i.id AS invitacion_id,
                COALESCE(i.estado, 'sin_emitir') AS invitacion_estado,
                i.emitida_at AS fecha,
                r.created_at AS orden_fecha
            FROM public.registros r
            LEFT JOIN public.promotoras m ON m.id = r.promotora_id
            LEFT JOIN public.asesores a ON a.id = r.asesor_id
            LEFT JOIN LATERAL (
                SELECT iv.id, iv.estado, iv.emitida_at
                FROM public.invitaciones iv
                WHERE iv.registro_id = r.id
                ORDER BY
                    CASE WHEN iv.estado <> 'revocada' THEN 0 ELSE 1 END,
                    iv.emitida_at DESC NULLS LAST,
                    iv.id DESC
                LIMIT 1
            ) i ON TRUE
            WHERE v_busqueda = '' OR strpos(
                lower(concat_ws(' ', m.nombres, m.apellidos,
                                r.folio, m.telefono_whatsapp, a.nombre)),
                v_busqueda
            ) > 0
        ),
        pagina AS (
            SELECT * FROM filtrados
            ORDER BY orden_fecha DESC NULLS LAST, registro_id DESC
            LIMIT v_limite OFFSET v_offset
        )
        SELECT
            (SELECT count(*) FROM filtrados),
            (SELECT COALESCE(
                jsonb_agg(to_jsonb(pg) - 'orden_fecha'
                          ORDER BY pg.orden_fecha DESC NULLS LAST, pg.registro_id DESC),
                '[]'::jsonb
            ) FROM pagina pg)
        INTO v_total, v_filas;
    END IF;

    RETURN jsonb_build_object(
        'total', v_total,
        'registros', COALESCE(v_filas, '[]'::jsonb)
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.bandejas_admin_paginadas(text,integer,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.bandejas_admin_paginadas(text,integer,text,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.comprobar_limite_login(p_clave_hash text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_ahora timestamptz := clock_timestamp();
    v_intentos integer;
BEGIN
    IF p_clave_hash IS NULL
       OR p_clave_hash !~ '^[a-f0-9]{64}$' THEN
        RAISE EXCEPTION 'Identificador inválido';
    END IF;

    INSERT INTO public.limites_inicio_sesion AS l (
        clave_hash,
        ventana_inicio,
        intentos
    )
    VALUES (p_clave_hash, v_ahora, 1)

    ON CONFLICT (clave_hash)
    DO UPDATE SET
        intentos = CASE
            WHEN l.ventana_inicio <= v_ahora - INTERVAL '15 minutes'
            THEN 1
            ELSE l.intentos + 1
        END,
        ventana_inicio = CASE
            WHEN l.ventana_inicio <= v_ahora - INTERVAL '15 minutes'
            THEN v_ahora
            ELSE l.ventana_inicio
        END

    RETURNING intentos INTO v_intentos;

    RETURN v_intentos <= 20;
END;
$function$
;
REVOKE ALL ON FUNCTION public.comprobar_limite_login(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.comprobar_limite_login(text) TO service_role;

CREATE OR REPLACE FUNCTION public.comprobar_limite_registro(p_clave text, p_max_intentos integer DEFAULT 5, p_ventana_minutos integer DEFAULT 15)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_intentos integer;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Operación no autorizada';
  END IF;

  IF p_clave IS NULL
     OR length(p_clave) < 16
     OR length(p_clave) > 200
     OR p_max_intentos < 1
     OR p_max_intentos > 100
     OR p_ventana_minutos < 1
     OR p_ventana_minutos > 1440
  THEN
    RAISE EXCEPTION 'Parámetros inválidos';
  END IF;

  INSERT INTO public.limites_registro AS l (
    clave,
    intentos,
    ventana_inicio
  )
  VALUES (
    p_clave,
    1,
    now()
  )
  ON CONFLICT (clave)
  DO UPDATE SET
    intentos = CASE
      WHEN l.ventana_inicio <
        now() - make_interval(mins => p_ventana_minutos)
      THEN 1
      ELSE l.intentos + 1
    END,
    ventana_inicio = CASE
      WHEN l.ventana_inicio <
        now() - make_interval(mins => p_ventana_minutos)
      THEN now()
      ELSE l.ventana_inicio
    END
  RETURNING intentos INTO v_intentos;

  RETURN v_intentos <= p_max_intentos;
END;
$function$
;
REVOKE ALL ON FUNCTION public.comprobar_limite_registro(text,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.comprobar_limite_registro(text,integer,integer) TO service_role;

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

CREATE OR REPLACE FUNCTION public.consultar_qr_acceso(p_token text)
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
    WHERE id = v_invitacion.registro_id;

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
REVOKE ALL ON FUNCTION public.consultar_qr_acceso(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.consultar_qr_acceso(text) TO authenticated;

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
REVOKE ALL ON FUNCTION public.consultar_qr_acceso_evento(text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.consultar_qr_acceso_evento(text,uuid) TO authenticated;

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
REVOKE ALL ON FUNCTION public.crear_inscripcion(uuid,text,text,text,text,uuid,text,text,text,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_inscripcion(uuid,text,text,text,text,uuid,text,text,text,uuid,text) TO service_role;

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
REVOKE ALL ON FUNCTION public.crear_registro_prueba_admin(uuid,uuid,text,text,text,text,text,text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_registro_prueba_admin(uuid,uuid,text,text,text,text,text,text,text,text,integer) TO service_role;

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
REVOKE ALL ON FUNCTION public.crear_registro_prueba_admin_v2(uuid,uuid,text,text,text,text,text,text,text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_registro_prueba_admin_v2(uuid,uuid,text,text,text,text,text,text,text,text,text,integer) TO service_role;

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
REVOKE ALL ON FUNCTION public.crear_registro_publico_v2(uuid,uuid,text,text,text,text,text,text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_registro_publico_v2(uuid,uuid,text,text,text,text,text,text,text,text,integer) TO service_role;

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
REVOKE ALL ON FUNCTION public.crear_registro_publico_v3(uuid,uuid,text,text,text,text,text,text,text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.crear_registro_publico_v3(uuid,uuid,text,text,text,text,text,text,text,text,text,integer) TO service_role;

CREATE OR REPLACE FUNCTION public.emitir_invitacion_admin_interna(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

DECLARE
    v_registro public.registros%ROWTYPE;
    v_existente public.invitaciones%ROWTYPE;

    v_token text;
    v_invitacion_id uuid;
    v_vault_id uuid;

BEGIN

    -- ======================================================
    -- A. Verificar inscripción
    -- ======================================================

    SELECT *
    INTO v_registro
    FROM public.registros
    WHERE id = p_registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inscripción inexistente';
    END IF;

    IF v_registro.estado IS DISTINCT FROM 'confirmado' THEN
        RAISE EXCEPTION
            'La inscripción no está confirmada';
    END IF;


    -- ======================================================
    -- B. Buscar invitación vigente
    -- ======================================================

    SELECT *
    INTO v_existente
    FROM public.invitaciones
    WHERE registro_id = p_registro_id
      AND estado IN ('emitida', 'activa')
    ORDER BY
        emitida_at DESC NULLS LAST,
        id DESC
    LIMIT 1
    FOR UPDATE;


    -- ======================================================
    -- C. CONSULTAR QR ORIGINAL
    --    No generar ni revocar otro QR.
    -- ======================================================

    IF FOUND AND NOT COALESCE(p_reemitir, false) THEN

        v_token := NULL;

        -- Los QR nuevos tendrán referencia en Vault.
        IF v_existente.token_vault_id IS NOT NULL THEN

            SELECT decrypted_secret
            INTO v_token
            FROM vault.decrypted_secrets
            WHERE id = v_existente.token_vault_id;

            -- Comprobar que el QR recuperado sea exactamente
            -- el mismo que identifica el hash almacenado.

            IF v_token IS NULL
               OR encode(
                    sha256(convert_to(v_token, 'UTF8')),
                    'hex'
                  ) IS DISTINCT FROM v_existente.token_hash
            THEN
                RAISE EXCEPTION
                    'No se pudo verificar el token original';
            END IF;

        END IF;

        RETURN jsonb_build_object(
            'invitacion_id', v_existente.id,
            'ya_existia', true,
            'token_qr', v_token
        );

    END IF;


    -- ======================================================
    -- D. REEMITIR QR
    --    Solamente cuando se solicita expresamente.
    -- ======================================================

    IF COALESCE(p_reemitir, false) THEN

        UPDATE public.invitaciones
        SET
            estado = 'revocada',
            revocada_at = now()
        WHERE registro_id = p_registro_id
          AND estado IN ('emitida', 'activa');

    END IF;


    -- ======================================================
    -- E. Crear nuevo código QR
    -- ======================================================

    v_token :=
        replace(gen_random_uuid()::text, '-', '') ||
        replace(gen_random_uuid()::text, '-', '');


    -- ======================================================
    -- F. Guardar el código cifrado en Supabase Vault.
    --    CORRECCIÓN: firma de cuatro parámetros.
    -- ======================================================

    v_vault_id := vault.create_secret(
        v_token,
        NULL::text,
        ''::text,
        NULL::uuid
    );


    -- ======================================================
    -- G. Guardar invitación.
    --    Solo se almacena su hash y referencia a Vault.
    -- ======================================================

    INSERT INTO public.invitaciones (
        registro_id,
        token_hash,
        token_vault_id,
        estado,
        emitida_por,
        emitida_at
    )
    VALUES (
        p_registro_id,
        encode(
            sha256(convert_to(v_token, 'UTF8')),
            'hex'
        ),
        v_vault_id,
        'emitida',
        p_admin_id,
        now()
    )
    RETURNING id INTO v_invitacion_id;


    -- ======================================================
    -- H. Conservar auditoría
    -- ======================================================

    INSERT INTO public.auditoria (
        usuario_id,
        accion,
        entidad,
        entidad_id,
        detalles
    )
    VALUES (
        p_admin_id,
        CASE
            WHEN COALESCE(p_reemitir, false)
                THEN 'reemitir_invitacion'
            ELSE 'emitir_invitacion'
        END,
        'invitaciones',
        v_invitacion_id,
        jsonb_build_object(
            'registro_id', p_registro_id
        )
    );


    -- ======================================================
    -- I. Devolver QR para mostrarlo en el panel
    -- ======================================================

    RETURN jsonb_build_object(
        'invitacion_id', v_invitacion_id,
        'ya_existia', false,
        'token_qr', v_token
    );

END;

$function$
;
REVOKE ALL ON FUNCTION public.emitir_invitacion_admin_interna(uuid,uuid,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.evitar_acceso_duplicado()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_registro_id uuid;
BEGIN
  SELECT registro_id
  INTO v_registro_id
  FROM public.invitaciones
  WHERE id = NEW.invitacion_id;

  IF v_registro_id IS NULL THEN
    RAISE EXCEPTION 'Invitación inexistente';
  END IF;

  -- Serializa los intentos de acceso
  -- correspondientes a la misma inscripción.
  PERFORM 1
  FROM public.registros
  WHERE id = v_registro_id
  FOR UPDATE;

  IF EXISTS (
    SELECT 1
    FROM public.accesos a
    JOIN public.invitaciones i
      ON i.id = a.invitacion_id
    WHERE i.registro_id = v_registro_id
  ) THEN
    RAISE EXCEPTION
      'Esta participante ya tiene un ingreso registrado';
  END IF;

  RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION public.evitar_acceso_duplicado() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.evitar_acceso_duplicado() TO PUBLIC;

CREATE OR REPLACE FUNCTION public.evitar_registro_duplicado()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_telefono text;
BEGIN
  SELECT p.telefono_whatsapp
  INTO v_telefono
  FROM public.promotoras AS p
  WHERE p.id = NEW.promotora_id;

  IF v_telefono IS NULL THEN
    RAISE EXCEPTION 'Participante no encontrada';
  END IF;

  -- Serializar intentos del mismo teléfono y evento.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      NEW.evento_id::text || ':' || v_telefono,
      0
    )
  );

  IF EXISTS (
    SELECT 1
    FROM public.registros AS r
    JOIN public.promotoras AS p
      ON p.id = r.promotora_id
    WHERE r.evento_id = NEW.evento_id
      AND p.telefono_whatsapp = v_telefono
      AND r.id IS DISTINCT FROM NEW.id
  ) THEN
    RAISE EXCEPTION
      'Este WhatsApp ya tiene una inscripción en el evento';
  END IF;

  RETURN NEW;
END;
$function$
;
REVOKE ALL ON FUNCTION public.evitar_registro_duplicado() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.evitar_registro_duplicado() TO PUBLIC;

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
GRANT EXECUTE ON FUNCTION public.impedir_sobrecupo_evento() TO PUBLIC;

CREATE OR REPLACE FUNCTION public.limpiar_limites_inicio_sesion()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_eliminados integer;
BEGIN
    DELETE FROM public.limites_inicio_sesion
    WHERE ventana_inicio < now() - INTERVAL '24 hours';

    GET DIAGNOSTICS v_eliminados = ROW_COUNT;

    RETURN v_eliminados;
END;
$function$
;
REVOKE ALL ON FUNCTION public.limpiar_limites_inicio_sesion() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.limpiar_limites_inicio_sesion() TO service_role;

CREATE OR REPLACE FUNCTION public.limpiar_limites_registro()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_eliminados integer;
BEGIN
    -- Solo permitir ejecución administrativa.
    IF auth.role() IS DISTINCT FROM 'service_role'
       AND session_user <> 'postgres'
    THEN
        RAISE EXCEPTION 'Operación no autorizada';
    END IF;

    DELETE FROM public.limites_registro
    WHERE ventana_inicio < now() - interval '48 hours';

    GET DIAGNOSTICS v_eliminados = ROW_COUNT;

    RETURN v_eliminados;
END;
$function$
;
REVOKE ALL ON FUNCTION public.limpiar_limites_registro() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.limpiar_limites_registro() TO service_role;

CREATE OR REPLACE FUNCTION public.obtener_eventos_publicos()
 RETURNS TABLE(id uuid, nombre text, descripcion text, fecha_inicio timestamp with time zone, sede text, cuota_fija numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT
    e.id,
    e.nombre,
    e.descripcion,
    e.fecha_inicio,
    e.sede,
    e.cuota_fija
  FROM public.eventos AS e
  WHERE e.estado = 'activo'
  ORDER BY e.fecha_inicio;
$function$
;
REVOKE ALL ON FUNCTION public.obtener_eventos_publicos() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.obtener_eventos_publicos() TO anon;
GRANT EXECUTE ON FUNCTION public.obtener_eventos_publicos() TO authenticated;

CREATE OR REPLACE FUNCTION public.obtener_rol_usuario(p_usuario_id uuid)
 RETURNS TABLE(nombre text, rol text, activo boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF auth.role() IS DISTINCT FROM 'service_role' THEN
        RAISE EXCEPTION 'Operación no autorizada';
    END IF;

    RETURN QUERY
    SELECT
        u.nombre,
        u.rol,
        u.activo
    FROM public.usuarios AS u
    WHERE u.id = p_usuario_id;
END;
$function$
;
REVOKE ALL ON FUNCTION public.obtener_rol_usuario(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.obtener_rol_usuario(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.operador_autorizado_evento(p_evento_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
    SELECT
        auth.uid() IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM public.usuarios u
            WHERE u.id = auth.uid()
              AND u.activo = true
              AND u.rol IN ('administrador', 'acceso')
        )
        AND EXISTS (
            SELECT 1
            FROM public.usuarios_eventos ue
            WHERE ue.usuario_id = auth.uid()
              AND ue.evento_id = p_evento_id
              AND ue.activo = true
        );
$function$
;
REVOKE ALL ON FUNCTION public.operador_autorizado_evento(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.proteger_ultimo_administrador_activo()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_deja_de_ser_admin boolean := false;
    v_administradores integer;
BEGIN
    -- Solo proteger cuentas que anteriormente
    -- eran administradores activos.
    IF OLD.rol IS DISTINCT FROM 'administrador'
       OR OLD.activo IS DISTINCT FROM TRUE THEN
        RETURN NULL;
    END IF;

    IF TG_OP = 'DELETE' THEN
        v_deja_de_ser_admin := true;
    ELSE
        v_deja_de_ser_admin :=
            NEW.rol IS DISTINCT FROM 'administrador'
            OR NEW.activo IS DISTINCT FROM TRUE;
    END IF;

    IF NOT v_deja_de_ser_admin THEN
        RETURN NULL;
    END IF;

    -- Serializar operaciones concurrentes sobre
    -- la protección del último administrador.
    PERFORM pg_catalog.pg_advisory_xact_lock(2026, 1001);

    SELECT COUNT(*)
    INTO v_administradores
    FROM public.usuarios
    WHERE rol = 'administrador'
      AND activo = TRUE;

    IF v_administradores < 1 THEN
        RAISE EXCEPTION
            'No se puede eliminar o desactivar al último administrador activo'
            USING ERRCODE = '23514';
    END IF;

    RETURN NULL;
END;
$function$
;
REVOKE ALL ON FUNCTION public.proteger_ultimo_administrador_activo() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.recuperar_invitacion_admin(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro public.registros%ROWTYPE;
    v_invitacion jsonb;
BEGIN
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Administrador no autorizado';
    END IF;

    SELECT *
    INTO v_registro
    FROM public.registros
    WHERE id = p_registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inscripción inexistente';
    END IF;

    -- Prohibir reactivar registros cerrados.
    IF v_registro.estado IN ('cancelado', 'rechazado') THEN
        RAISE EXCEPTION
            'No se pueden recuperar invitaciones de inscripciones canceladas o rechazadas';
    END IF;

    IF NOT COALESCE(v_registro.exento_pago, false)
       AND NOT EXISTS (
           SELECT 1
           FROM public.pagos
           WHERE registro_id = p_registro_id
             AND estado = 'validado'
       )
    THEN
        RAISE EXCEPTION 'Sin pago validado ni cortesía';
    END IF;

    UPDATE public.registros
    SET estado = 'confirmado'
    WHERE id = p_registro_id;

    v_invitacion :=
        public.emitir_invitacion_admin_interna(
            p_registro_id,
            p_admin_id,
            p_reemitir
        );

    RETURN jsonb_build_object(
        'ok', true,
        'registro_id', p_registro_id,
        'invitacion', v_invitacion
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.recuperar_invitacion_admin(uuid,uuid,boolean) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.recuperar_invitacion_admin(uuid,uuid,boolean) TO service_role;

CREATE OR REPLACE FUNCTION public.registrar_entrada_qr(p_token text)
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
  WHERE id = v_invitacion.registro_id
  FOR UPDATE;

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
REVOKE ALL ON FUNCTION public.registrar_entrada_qr(text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_qr(text) TO authenticated;

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
REVOKE ALL ON FUNCTION public.registrar_entrada_qr_evento(text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_qr_evento(text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.resumen_cupo_evento_interno(p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_cupo integer;
    v_ocupados bigint;
    v_cortesias bigint;
    v_con_pago bigint;
    v_cortesias_pendientes bigint;
    v_pendientes bigint;
    v_pruebas bigint;
BEGIN
    SELECT cupo_maximo
    INTO v_cupo
    FROM public.configuracion_cupo_evento
    WHERE evento_id = p_evento_id;

    IF v_cupo IS NULL OR v_cupo < 1 THEN
        RAISE EXCEPTION 'Cupo del evento no configurado';
    END IF;

    SELECT
        COUNT(*) FILTER (
            WHERE NOT COALESCE(r.es_prueba, false)
              AND COALESCE(r.estado, 'pendiente')
                  NOT IN ('cancelado', 'rechazado')
        ),

        COUNT(*) FILTER (
            WHERE NOT COALESCE(r.es_prueba, false)
              AND COALESCE(r.estado, 'pendiente')
                  NOT IN ('cancelado', 'rechazado')
              AND COALESCE(r.exento_pago, false)
        ),

        COUNT(*) FILTER (
            WHERE NOT COALESCE(r.es_prueba, false)
              AND COALESCE(r.estado, 'pendiente')
                  NOT IN ('cancelado', 'rechazado')
              AND p.tipo_participante = 'vendedora'
              AND NOT COALESCE(r.exento_pago, false)
        ),

        COUNT(*) FILTER (
            WHERE NOT COALESCE(r.es_prueba, false)
              AND COALESCE(r.estado, 'pendiente')
                  NOT IN ('cancelado', 'rechazado')
              AND p.tipo_participante = 'promotora'
              AND NOT COALESCE(r.exento_pago, false)
        ),

        COUNT(*) FILTER (
            WHERE NOT COALESCE(r.es_prueba, false)
              AND r.estado = 'pendiente'
        ),

        COUNT(*) FILTER (
            WHERE COALESCE(r.es_prueba, false)
        )

    INTO
        v_ocupados,
        v_cortesias,
        v_con_pago,
        v_cortesias_pendientes,
        v_pendientes,
        v_pruebas

    FROM public.registros r
    JOIN public.promotoras p
      ON p.id = r.promotora_id
    WHERE r.evento_id = p_evento_id;

    RETURN jsonb_build_object(
        'capacidad', v_cupo,
        'ocupados', v_ocupados,
        'disponibles', GREATEST(v_cupo - v_ocupados, 0),
        'cortesias', v_cortesias,
        'con_pago', v_con_pago,
        'cortesias_pendientes', v_cortesias_pendientes,
        'pendientes', v_pendientes,
        'pruebas', v_pruebas,
        'porcentaje',
            ROUND(100.0 * v_ocupados / v_cupo, 1)
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.resumen_cupo_evento_interno(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.resumen_cupo_evento_interno(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.validar_pago_admin(p_pago_id uuid, p_accion text, p_motivo text, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_pago public.pagos%ROWTYPE;
    v_registro public.registros%ROWTYPE;
    v_estado text;
    v_motivo text;
    v_invitacion jsonb := NULL;
BEGIN
    -- Conservar la autorización administrativa existente.
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Administrador no autorizado';
    END IF;

    IF p_pago_id IS NULL
       OR p_accion IS NULL
       OR p_accion NOT IN ('aprobar', 'rechazar')
    THEN
        RAISE EXCEPTION 'Solicitud inválida';
    END IF;

    v_motivo := NULLIF(btrim(p_motivo), '');

    IF p_accion = 'rechazar'
       AND length(coalesce(v_motivo, '')) < 5
    THEN
        RAISE EXCEPTION 'Motivo obligatorio';
    END IF;

    IF length(coalesce(v_motivo, '')) > 500 THEN
        RAISE EXCEPTION 'Motivo demasiado largo';
    END IF;

    -- Bloquear el pago durante la operación.
    SELECT *
    INTO v_pago
    FROM public.pagos
    WHERE id = p_pago_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pago inexistente';
    END IF;

    IF v_pago.estado IS DISTINCT FROM 'pendiente' THEN
        RAISE EXCEPTION 'El pago ya fue procesado';
    END IF;

    -- Bloquear también la inscripción asociada.
    SELECT *
    INTO v_registro
    FROM public.registros
    WHERE id = v_pago.registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inscripción inexistente';
    END IF;

    -- CORRECCIÓN 1:
    -- No procesar pagos de inscripciones cerradas.
    IF v_registro.estado IN ('cancelado', 'rechazado') THEN
        RAISE EXCEPTION
            'No se pueden validar pagos de inscripciones canceladas o rechazadas';
    END IF;

    IF p_accion = 'aprobar' THEN

        -- Conservar la protección de cortesías.
        IF coalesce(v_registro.exento_pago, FALSE) THEN
            RAISE EXCEPTION
                'Esta inscripción ya tiene cortesía';
        END IF;

        -- CORRECCIÓN 2:
        -- Impedir otro pago validado para el mismo registro.
        IF EXISTS (
            SELECT 1
            FROM public.pagos
            WHERE registro_id = v_pago.registro_id
              AND estado = 'validado'
              AND id <> p_pago_id
        ) THEN
            RAISE EXCEPTION
                'Ya existe un pago validado para esta inscripción';
        END IF;

    END IF;

    v_estado := CASE
        WHEN p_accion = 'aprobar' THEN 'validado'
        ELSE 'rechazado'
    END;

    UPDATE public.pagos
    SET estado = v_estado,
        validado_por = p_admin_id,
        validado_at = now()
    WHERE id = p_pago_id;

    -- Conservar la auditoría.
    INSERT INTO public.auditoria (
        usuario_id,
        accion,
        entidad,
        entidad_id,
        detalles
    )
    VALUES (
        p_admin_id,
        CASE
            WHEN p_accion = 'aprobar'
                THEN 'aprobar_pago'
            ELSE 'rechazar_pago'
        END,
        'pagos',
        p_pago_id,
        jsonb_build_object(
            'registro_id', v_pago.registro_id,
            'estado_anterior', v_pago.estado,
            'estado_nuevo', v_estado,
            'importe', v_pago.importe,
            'motivo', v_motivo
        )
    );

    IF p_accion = 'aprobar' THEN

        UPDATE public.registros
        SET estado = 'confirmado'
        WHERE id = v_pago.registro_id;

        -- Conservar el flujo de invitaciones existente.
        v_invitacion :=
            public.emitir_invitacion_admin_interna(
                v_pago.registro_id,
                p_admin_id,
                FALSE
            );

    END IF;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'pago_id', p_pago_id,
        'estado', v_estado,
        'invitacion', v_invitacion
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.validar_pago_admin(uuid,text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.validar_pago_admin(uuid,text,text,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.validar_pago_personal(p_pago_id uuid, p_accion text, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_operador uuid;
    v_pago public.pagos%ROWTYPE;
    v_registro public.registros%ROWTYPE;
    v_motivo text;
    v_estado text;
    v_invitacion jsonb := NULL;
BEGIN
    v_operador := auth.uid();

    IF v_operador IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = v_operador
          AND activo = TRUE
          AND rol = 'validador'
    ) THEN
        RAISE EXCEPTION
            'Se requiere una cuenta activa de validador';
    END IF;

    IF p_pago_id IS NULL
       OR p_accion IS NULL
       OR p_accion NOT IN ('aprobar', 'rechazar')
    THEN
        RAISE EXCEPTION 'Acción inválida';
    END IF;

    v_motivo := NULLIF(btrim(p_motivo), '');

    IF p_accion = 'rechazar'
       AND length(coalesce(v_motivo, '')) < 5
    THEN
        RAISE EXCEPTION
            'El rechazo requiere un motivo de al menos cinco caracteres';
    END IF;

    IF length(coalesce(v_motivo, '')) > 500 THEN
        RAISE EXCEPTION 'Motivo demasiado largo';
    END IF;

    SELECT *
    INTO v_pago
    FROM public.pagos
    WHERE id = p_pago_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago no existe';
    END IF;

    IF v_pago.estado IS DISTINCT FROM 'pendiente' THEN
        RAISE EXCEPTION 'Este pago ya no está pendiente';
    END IF;

    SELECT *
    INTO v_registro
    FROM public.registros
    WHERE id = v_pago.registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La inscripción no existe';
    END IF;

    -- CORRECCIÓN DE SEGURIDAD:
    -- Bloquear inscripciones canceladas Y rechazadas.
    IF v_registro.estado IN ('cancelado', 'rechazado') THEN
        RAISE EXCEPTION
            'No se pueden validar pagos de inscripciones canceladas o rechazadas';
    END IF;

    IF p_accion = 'aprobar' THEN
        IF coalesce(v_registro.exento_pago, FALSE) THEN
            RAISE EXCEPTION
                'Esta inscripción ya tiene una cortesía';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM public.pagos
            WHERE registro_id = v_pago.registro_id
              AND estado = 'validado'
              AND id <> p_pago_id
        ) THEN
            RAISE EXCEPTION
                'Ya existe un pago validado para esta inscripción';
        END IF;
    END IF;

    v_estado := CASE
        WHEN p_accion = 'aprobar' THEN 'validado'
        ELSE 'rechazado'
    END;

    UPDATE public.pagos
    SET estado = v_estado,
        validado_por = v_operador,
        validado_at = now()
    WHERE id = p_pago_id;

    INSERT INTO public.auditoria (
        usuario_id,
        accion,
        entidad,
        entidad_id,
        detalles
    )
    VALUES (
        v_operador,
        CASE
            WHEN p_accion = 'aprobar'
                THEN 'aprobar_pago'
            ELSE 'rechazar_pago'
        END,
        'pagos',
        p_pago_id,
        jsonb_build_object(
            'registro_id', v_pago.registro_id,
            'estado_anterior', v_pago.estado,
            'estado_nuevo', v_estado,
            'importe', v_pago.importe,
            'motivo', v_motivo,
            'rol_operador', 'validador'
        )
    );

    IF p_accion = 'aprobar' THEN
        UPDATE public.registros
        SET estado = 'confirmado'
        WHERE id = v_pago.registro_id;

        v_invitacion :=
            public.emitir_invitacion_admin_interna(
                v_pago.registro_id,
                v_operador,
                FALSE
            );
    END IF;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'pago_id', p_pago_id,
        'estado', v_estado,
        'invitacion', v_invitacion
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.validar_pago_personal(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.validar_pago_personal(uuid,text,text) TO authenticated;
DROP FUNCTION IF EXISTS public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text);
DROP FUNCTION IF EXISTS public.bandejas_admin_chiapas_paginadas(text,integer,text,uuid);
DROP FUNCTION IF EXISTS public.recuperar_invitacion_admin_chiapas(uuid,uuid,boolean);
DROP FUNCTION IF EXISTS public.autorizar_cortesia_admin_chiapas(uuid,uuid);
DROP FUNCTION IF EXISTS public.validar_pago_admin_chiapas(uuid,text,text,uuid);
DROP FUNCTION IF EXISTS public.validar_pago_personal_chiapas(uuid,text,text);
DROP FUNCTION IF EXISTS public.emitir_invitacion_chiapas_interna(uuid,uuid,boolean);
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
