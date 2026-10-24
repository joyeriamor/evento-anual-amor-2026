BEGIN;

-- Cancelar si la funcion activa cambio desde el respaldo.
DO $verificacion$
BEGIN
    IF md5(pg_get_functiondef(
        'public.validar_pago_personal(uuid,text,text)'::regprocedure
    )) <> 'd6f4bab8e43fa8a99dca3d2e1508d14e'
    THEN
        RAISE EXCEPTION
            'La funcion original cambio. Migracion cancelada.';
    END IF;
END;
$verificacion$;

CREATE OR REPLACE FUNCTION pg_temp.validar_pago_personal_ensayo(p_pago_id uuid, p_accion text, p_motivo text DEFAULT NULL::text)
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
    -- PROTECCION MULTIEVENTO:
    -- Esta funcion heredada solo procesa RADEV'S.
    -- No modificar el rol del validador existente.
    IF v_registro.evento_id IS DISTINCT FROM
       '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    THEN
        RAISE EXCEPTION
            'Este pago pertenece a otro evento';
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
$function$;

-- PRUEBAS AISLADAS: NO MODIFICAR LA FUNCION PUBLICA.

DO $preparacion$
DECLARE
    v_validador uuid;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE oid =
          'pg_temp.validar_pago_personal_ensayo(uuid,text,text)'::regprocedure
          AND prosecdef = true
    ) THEN
        RAISE EXCEPTION 'La copia no conserva SECURITY DEFINER';
    END IF;

    IF position(
        'v_registro.evento_id IS DISTINCT FROM'
        IN pg_get_functiondef(
          'pg_temp.validar_pago_personal_ensayo(uuid,text,text)'::regprocedure
        )
    ) = 0 THEN
        RAISE EXCEPTION 'Falta la proteccion de evento';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.pagos
        WHERE id = '00000000-0000-0000-0000-000000000000'::uuid
    ) THEN
        RAISE EXCEPTION 'El UUID ficticio ya existe';
    END IF;

    SELECT id INTO v_validador
    FROM public.usuarios
    WHERE activo = true AND rol = 'validador'
    LIMIT 1;

    IF v_validador IS NULL THEN
        RAISE EXCEPTION 'No existe un validador activo';
    END IF;

    PERFORM set_config(
        'request.jwt.claim.sub',
        v_validador::text,
        true
    );
END;
$preparacion$;

SET LOCAL ROLE authenticated;

DO $prueba$
DECLARE
    v_error text;
BEGIN
    BEGIN
        PERFORM pg_temp.validar_pago_personal_ensayo(
            '00000000-0000-0000-0000-000000000000'::uuid,
            'aprobar',
            NULL
        );

        RAISE EXCEPTION 'La funcion acepto un pago inexistente';

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

        IF v_error <> 'El pago no existe' THEN
            RAISE EXCEPTION 'Resultado inesperado: %', v_error;
        END IF;
    END;
END;
$prueba$;

SELECT
    'APROBADO' AS resultado,
    'Copia temporal y autorizacion verificadas' AS detalle;

ROLLBACK;