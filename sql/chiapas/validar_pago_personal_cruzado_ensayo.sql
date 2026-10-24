BEGIN;

-- TABLAS FICTICIAS: NINGUNA FILA REAL SE COPIA.
CREATE TEMP TABLE usuarios_eventos
AS SELECT * FROM public.usuarios_eventos WHERE FALSE;

CREATE TEMP TABLE registros
AS SELECT * FROM public.registros WHERE FALSE;

CREATE TEMP TABLE pagos
AS SELECT * FROM public.pagos WHERE FALSE;

CREATE TEMP TABLE auditoria
AS SELECT * FROM public.auditoria WHERE FALSE;

-- Impedir emitir invitaciones durante cualquier prueba.
CREATE FUNCTION pg_temp.emitir_invitacion_admin_interna_ensayo(
    p_registro_id uuid,
    p_admin_id uuid,
    p_reemitir boolean
)
RETURNS jsonb
LANGUAGE plpgsql
AS $aislamiento$
BEGIN
    RAISE EXCEPTION
        'Prohibido emitir invitaciones durante el ensayo';
END;
$aislamiento$;
DO $comprobacion$
BEGIN
    IF md5(pg_get_functiondef(
        'public.validar_pago_personal(uuid,text,text)'::regprocedure
    )) <> 'd6f4bab8e43fa8a99dca3d2e1508d14e'
    THEN
        RAISE EXCEPTION
            'La funcion original cambio. Revisar antes de continuar.';
    END IF;
END;
$comprobacion$;


CREATE FUNCTION pg_temp.validar_pago_personal_cruzado_ensayo(p_pago_id uuid, p_accion text, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_operador uuid;
    v_pago pg_temp.pagos%ROWTYPE;
    v_registro pg_temp.registros%ROWTYPE;
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

    -- SEGURIDAD CHIAPAS:
    -- Exigir asignacion activa al evento.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador
          AND ue.evento_id =
              '3dc92160-79af-4bf7-b770-263038e88900'::uuid
          AND ue.activo = TRUE
    ) THEN
        RAISE EXCEPTION
            'Validador sin permiso activo para Chiapas';
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
    FROM pg_temp.pagos
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
    FROM pg_temp.registros
    WHERE id = v_pago.registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La inscripción no existe';
    END IF;

    -- CORRECCIÓN DE SEGURIDAD:
    -- Bloquear inscripciones canceladas Y rechazadas.
    -- SEGURIDAD CHIAPAS:
    -- Impedir procesar pagos de cualquier otro evento.
    IF v_registro.evento_id IS DISTINCT FROM
       '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    THEN
        RAISE EXCEPTION
            'El pago no pertenece a Chiapas';
    END IF;

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
            FROM pg_temp.pagos
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

    UPDATE pg_temp.pagos
    SET estado = v_estado,
        validado_por = v_operador,
        validado_at = now()
    WHERE id = p_pago_id;

    INSERT INTO pg_temp.auditoria (
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
        UPDATE pg_temp.registros
        SET estado = 'confirmado'
        WHERE id = v_pago.registro_id;

        v_invitacion :=
            pg_temp.emitir_invitacion_admin_interna_ensayo(
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
$function$;

-- Preparar operador y asignacion SIMULADA.
DO $preparar_datos$
DECLARE
    v_validador uuid;
BEGIN
    SELECT id INTO v_validador
    FROM public.usuarios
    WHERE rol = 'validador'
      AND activo = TRUE
    LIMIT 1;

    IF v_validador IS NULL THEN
        RAISE EXCEPTION 'No existe validador activo';
    END IF;

    INSERT INTO pg_temp.usuarios_eventos (
        usuario_id, evento_id, activo
    )
    VALUES (
        v_validador,
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid,
        TRUE
    );

    -- Registro ficticio de RADEV'S.
    INSERT INTO pg_temp.registros (
        id, evento_id, estado, exento_pago
    )
    VALUES (
        '11111111-1111-4111-8111-111111111111',
        '43e67bda-d19d-4c0e-a639-e85f2d62f294',
        'pendiente',
        FALSE
    );

    INSERT INTO pg_temp.pagos (
        id, registro_id, importe, estado
    )
    VALUES (
        '22222222-2222-4222-8222-222222222222',
        '11111111-1111-4111-8111-111111111111',
        300,
        'pendiente'
    );

    -- Registro ficticio de Chiapas.
    INSERT INTO pg_temp.registros (
        id, evento_id, estado, exento_pago
    )
    VALUES (
        '33333333-3333-4333-8333-333333333333',
        '3dc92160-79af-4bf7-b770-263038e88900',
        'pendiente',
        FALSE
    );

    INSERT INTO pg_temp.pagos (
        id, registro_id, importe, estado
    )
    VALUES (
        '44444444-4444-4444-8444-444444444444',
        '33333333-3333-4333-8333-333333333333',
        300,
        'pendiente'
    );

    PERFORM set_config(
        'request.jwt.claim.sub',
        v_validador::text,
        TRUE
    );
END;
$preparar_datos$;

SET LOCAL ROLE authenticated;

DO $verificar$
DECLARE
    v_mensaje text;
    v_resultado jsonb;
BEGIN
    -- PRUEBA 1: pago de RADEV'S debe rechazarse.
    BEGIN
        PERFORM pg_temp.validar_pago_personal_cruzado_ensayo(
            '22222222-2222-4222-8222-222222222222',
            'rechazar',
            'Motivo ficticio de prueba'
        );

        RAISE EXCEPTION
            'ERROR: se acepto un pago de RADEVS';

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_mensaje = MESSAGE_TEXT;

        IF v_mensaje <> 'El pago no pertenece a Chiapas' THEN
            RAISE EXCEPTION
                'Fallo prueba RADEVS: %', v_mensaje;
        END IF;
    END;

    -- PRUEBA 2: pago de Chiapas debe procesarse.
    v_resultado :=
        pg_temp.validar_pago_personal_cruzado_ensayo(
            '44444444-4444-4444-8444-444444444444',
            'rechazar',
            'Motivo ficticio de prueba'
        );

    IF v_resultado->>'ok' <> 'true'
       OR v_resultado->>'estado' <> 'rechazado'
    THEN
        RAISE EXCEPTION
            'Fallo prueba Chiapas: %', v_resultado;
    END IF;
END;
$verificar$;

RESET ROLE;

-- Verificar efectos exclusivamente sobre tablas temporales.
DO $comprobar$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.pagos
        WHERE id = '22222222-2222-4222-8222-222222222222'
          AND estado = 'pendiente'
    ) THEN
        RAISE EXCEPTION 'Se altero el pago ficticio de RADEVS';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.pagos
        WHERE id = '44444444-4444-4444-8444-444444444444'
          AND estado = 'rechazado'
    ) THEN
        RAISE EXCEPTION 'No se proceso el pago ficticio Chiapas';
    END IF;

    IF (SELECT count(*) FROM pg_temp.auditoria) <> 1 THEN
        RAISE EXCEPTION 'Auditoria ficticia incorrecta';
    END IF;
END;
$comprobar$;

SELECT
    'APROBADO' AS resultado,
    'Pago RADEVS bloqueado; pago Chiapas procesado en tablas temporales' AS detalle;

ROLLBACK;