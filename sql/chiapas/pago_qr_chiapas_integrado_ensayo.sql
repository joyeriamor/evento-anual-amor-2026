BEGIN;

-- Comprobar version real sin modificarla.
DO $version$
BEGIN
    IF md5(pg_get_functiondef(
        'public.emitir_invitacion_admin_interna(uuid,uuid,boolean)'::regprocedure
    )) <> '1447b79ee3ac3bf82835f1f2e0490bef'
    THEN
        RAISE EXCEPTION 'Cambio inesperado del generador original';
    END IF;
END;
$version$;

CREATE TEMP TABLE usuarios
AS SELECT * FROM public.usuarios WHERE FALSE;
CREATE TEMP TABLE registros
AS SELECT * FROM public.registros WHERE FALSE;

CREATE TEMP TABLE pagos
AS SELECT * FROM public.pagos WHERE FALSE;

CREATE TEMP TABLE invitaciones
AS SELECT * FROM public.invitaciones WHERE FALSE;

CREATE TEMP TABLE auditoria
AS SELECT * FROM public.auditoria WHERE FALSE;

CREATE TEMP TABLE usuarios_eventos
AS SELECT * FROM public.usuarios_eventos WHERE FALSE;

-- Permiso exclusivo para la asignacion ficticia del ensayo.
-- La transaccion finaliza en ROLLBACK.
GRANT INSERT ON TABLE pg_temp.usuarios_eventos TO authenticated;

-- CREATE TABLE AS SELECT no conserva los DEFAULT.
ALTER TABLE pg_temp.invitaciones
ALTER COLUMN id SET DEFAULT gen_random_uuid();

CREATE TEMP TABLE vault_decrypted_ensayo (
    id uuid PRIMARY KEY,
    decrypted_secret text NOT NULL
);

-- Sustituto de Vault: guarda secretos SOLO en pg_temp.
CREATE FUNCTION pg_temp.crear_secreto_ensayo(
    p_valor text,
    p_nombre text,
    p_descripcion text,
    p_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $vault_ficticio$
DECLARE
    v_id uuid := gen_random_uuid();
BEGIN
    INSERT INTO pg_temp.vault_decrypted_ensayo (
        id, decrypted_secret
    )
    VALUES (v_id, p_valor);

    RETURN v_id;
END;
$vault_ficticio$;

CREATE OR REPLACE FUNCTION pg_temp.emitir_invitacion_chiapas_ensayo(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

DECLARE
    v_registro pg_temp.registros%ROWTYPE;
    v_existente pg_temp.invitaciones%ROWTYPE;

    v_token text;
    v_invitacion_id uuid;
    v_vault_id uuid;

BEGIN

    -- ======================================================
    -- A. Verificar inscripción
    -- ======================================================

    SELECT *
    INTO v_registro
    FROM pg_temp.registros
    WHERE id = p_registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inscripción inexistente';
    END IF;

    -- SEGURIDAD MULTIEVENTO: SOLO CHIAPAS.
    IF v_registro.evento_id IS DISTINCT FROM
       '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    THEN
        RAISE EXCEPTION
            'Operacion exclusiva de Chiapas';
    END IF;

    -- El operador debe estar activo y asignado a Chiapas.
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios u
        JOIN pg_temp.usuarios_eventos ue
          ON ue.usuario_id = u.id
        WHERE u.id = p_admin_id
          AND u.activo IS TRUE
          AND u.rol IN ('administrador', 'validador')
          AND ue.evento_id =
              '3dc92160-79af-4bf7-b770-263038e88900'::uuid
          AND ue.activo IS TRUE
    ) THEN
        RAISE EXCEPTION
            'Operador de Chiapas no autorizado';
    END IF;

    -- Si existe identidad JWT, debe coincidir.
    IF auth.uid() IS NOT NULL
       AND auth.uid() IS DISTINCT FROM p_admin_id
    THEN
        RAISE EXCEPTION
            'Identidad de operador incorrecta';
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
    FROM pg_temp.invitaciones
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
            FROM pg_temp.vault_decrypted_ensayo
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

        UPDATE pg_temp.invitaciones
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

    v_vault_id := pg_temp.crear_secreto_ensayo(
        v_token,
        NULL::text,
        ''::text,
        NULL::uuid
    );


    -- ======================================================
    -- G. Guardar invitación.
    --    Solo se almacena su hash y referencia a Vault.
    -- ======================================================

    INSERT INTO pg_temp.invitaciones (
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

    INSERT INTO pg_temp.auditoria (
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

$function$;



CREATE OR REPLACE FUNCTION pg_temp.validar_pago_chiapas_integrado_ensayo(p_pago_id uuid, p_accion text, p_motivo text DEFAULT NULL::text)
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
        FROM pg_temp.usuarios
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
            pg_temp.emitir_invitacion_chiapas_ensayo(
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

-- ENSAYO INTEGRADO EXCLUSIVAMENTE TEMPORAL.
-- El JWT simulado solamente existe en esta transaccion.
-- No se crean usuarios reales ni secretos en Vault.

DO $version_pago$
BEGIN
    IF md5(pg_get_functiondef(
        'public.validar_pago_personal(uuid,text,text)'::regprocedure
    )) <> 'd6f4bab8e43fa8a99dca3d2e1508d14e'
    THEN
        RAISE EXCEPTION 'Cambio inesperado en pagos originales';
    END IF;
END;
$version_pago$;

DO $datos$
BEGIN
    INSERT INTO pg_temp.usuarios (
        id, nombre, rol, activo
    )
    VALUES (
        '99111111-1111-4111-8111-111111111111',
        'Validador ficticio Chiapas',
        'validador',
        TRUE
    );

    INSERT INTO pg_temp.registros (
        id, evento_id, estado, exento_pago
    )
    VALUES
    (
        '22222222-2222-4222-8222-222222222221',
        '3dc92160-79af-4bf7-b770-263038e88900',
        'pendiente',
        FALSE
    ),
    (
        '22222222-2222-4222-8222-222222222222',
        '43e67bda-d19d-4c0e-a639-e85f2d62f294',
        'pendiente',
        FALSE
    );

    INSERT INTO pg_temp.pagos (
        id, registro_id, importe, estado
    )
    VALUES
    (
        '33333333-3333-4333-8333-333333333331',
        '22222222-2222-4222-8222-222222222221',
        300,
        'pendiente'
    ),
    (
        '33333333-3333-4333-8333-333333333332',
        '22222222-2222-4222-8222-222222222222',
        300,
        'pendiente'
    );

    PERFORM set_config(
        'request.jwt.claim.sub',
        '99111111-1111-4111-8111-111111111111',
        TRUE
    );
END;
$datos$;

SET LOCAL ROLE authenticated;

-- CASO 1: validador sin asignacion.
DO $sin_asignacion$
DECLARE
    v_error text;
BEGIN
    BEGIN
        PERFORM pg_temp.validar_pago_chiapas_integrado_ensayo(
            '33333333-3333-4333-8333-333333333331',
            'aprobar',
            NULL
        );

        RAISE EXCEPTION 'Pago aceptado sin asignacion';

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

        IF v_error NOT ILIKE '%asign%'
           AND v_error NOT ILIKE '%Chiapas%'
           AND v_error NOT ILIKE '%autoriz%'
        THEN
            RAISE EXCEPTION
                'Error inesperado sin asignacion: %', v_error;
        END IF;
    END;
END;
$sin_asignacion$;

RESET ROLE;

-- Asignacion ficticia, nunca sobre usuarios_eventos real.
INSERT INTO pg_temp.usuarios_eventos (
    usuario_id, evento_id, activo
)
VALUES (
    '99111111-1111-4111-8111-111111111111',
    '3dc92160-79af-4bf7-b770-263038e88900',
    TRUE
);

SET LOCAL ROLE authenticated;

DO $integracion$
DECLARE
    v_error text;
    v_resultado jsonb;
    v_token text;
BEGIN
    -- CASO 2: bloquear pago de RADEV'S.
    BEGIN
        PERFORM pg_temp.validar_pago_chiapas_integrado_ensayo(
            '33333333-3333-4333-8333-333333333332',
            'rechazar',
            'Motivo ficticio'
        );

        RAISE EXCEPTION 'Pago RADEVS aceptado';

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

        IF v_error <> 'El pago no pertenece a Chiapas' THEN
            RAISE EXCEPTION
                'Bloqueo de evento incorrecto: %', v_error;
        END IF;
    END;

    -- CASO 3: validar pago de Chiapas y emitir QR.
    v_resultado :=
        pg_temp.validar_pago_chiapas_integrado_ensayo(
            '33333333-3333-4333-8333-333333333331',
            'aprobar',
            NULL
        );

    v_token := v_resultado->'invitacion'->>'token_qr';

    IF v_resultado->>'estado' IS DISTINCT FROM 'validado'
       OR v_resultado->'invitacion'->>'ya_existia'
          IS DISTINCT FROM 'false'
       OR length(coalesce(v_token, '')) <> 64
    THEN
        RAISE EXCEPTION
            'No se aprobo pago con QR nuevo';
    END IF;

    -- CASO 4: impedir procesar nuevamente el mismo pago.
    BEGIN
        PERFORM pg_temp.validar_pago_chiapas_integrado_ensayo(
            '33333333-3333-4333-8333-333333333331',
            'aprobar',
            NULL
        );

        RAISE EXCEPTION 'Se proceso dos veces el pago';

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

        IF v_error NOT ILIKE '%pendiente%' THEN
            RAISE EXCEPTION
                'Error inesperado en doble procesamiento: %',
                v_error;
        END IF;
    END;
END;
$integracion$;

RESET ROLE;

DO $comprobar$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.pagos
        WHERE id = '33333333-3333-4333-8333-333333333331'
          AND estado = 'validado'
    ) THEN
        RAISE EXCEPTION 'Pago Chiapas no validado';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.registros
        WHERE id = '22222222-2222-4222-8222-222222222221'
          AND estado = 'confirmado'
    ) THEN
        RAISE EXCEPTION 'Registro Chiapas no confirmado';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.pagos
        WHERE id = '33333333-3333-4333-8333-333333333332'
          AND estado = 'pendiente'
    ) THEN
        RAISE EXCEPTION 'Pago RADEVS modificado';
    END IF;

    IF (SELECT COUNT(*) FROM pg_temp.invitaciones) <> 1 THEN
        RAISE EXCEPTION 'Cantidad incorrecta de QR';
    END IF;

    IF (SELECT COUNT(*) FROM pg_temp.vault_decrypted_ensayo) <> 1 THEN
        RAISE EXCEPTION 'Vault ficticio inconsistente';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_temp.invitaciones i
        JOIN pg_temp.vault_decrypted_ensayo v
          ON v.id = i.token_vault_id
        WHERE i.registro_id =
            '22222222-2222-4222-8222-222222222221'
          AND i.estado = 'emitida'
          AND i.token_hash = encode(
              sha256(convert_to(v.decrypted_secret, 'UTF8')),
              'hex'
          )
    ) THEN
        RAISE EXCEPTION 'Hash QR incorrecto';
    END IF;

    IF (SELECT COUNT(*) FROM pg_temp.auditoria) <> 2 THEN
        RAISE EXCEPTION 'Auditoria ficticia incorrecta';
    END IF;
END;
$comprobar$;

SELECT
    'APROBADO' AS resultado,
    'Pago Chiapas y QR integrados; acceso, cruce y duplicado bloqueados'
        AS detalle;

ROLLBACK;