BEGIN;

CREATE TEMP TABLE registros
AS SELECT * FROM public.registros WHERE FALSE;

CREATE TEMP TABLE pagos
AS SELECT * FROM public.pagos WHERE FALSE;

CREATE TEMP TABLE invitaciones
AS SELECT * FROM public.invitaciones WHERE FALSE;

CREATE TEMP TABLE auditoria
AS SELECT * FROM public.auditoria WHERE FALSE;

CREATE TEMP TABLE vault_bloqueado_ensayo (
    id uuid,
    decrypted_secret text
);

CREATE FUNCTION pg_temp.vault_bloqueado_ensayo(
    text, text, text, uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $vault$
BEGIN
    RAISE EXCEPTION 'Vault deshabilitado durante el ensayo';
END;
$vault$;



-- Evitar sobrescribir funciones que hayan cambiado.
DO $verificacion$
BEGIN
    IF md5(pg_get_functiondef(
        'public.validar_pago_admin(uuid,text,text,uuid)'::regprocedure
    )) <> '1d9dda43554b32a8f75ecec77e17fcfe' THEN
        RAISE EXCEPTION 'Cambio inesperado en validar_pago_admin';
    END IF;

    IF md5(pg_get_functiondef(
        'public.autorizar_cortesia_admin(uuid,uuid)'::regprocedure
    )) <> '4d53670065863b2915614991c74cc2f6' THEN
        RAISE EXCEPTION 'Cambio inesperado en autorizar_cortesia_admin';
    END IF;

    IF md5(pg_get_functiondef(
        'public.recuperar_invitacion_admin(uuid,uuid,boolean)'::regprocedure
    )) <> 'ca42ec72b3b0f2b482d6c3b8e4a760ca' THEN
        RAISE EXCEPTION 'Cambio inesperado en recuperar_invitacion_admin';
    END IF;

    IF md5(pg_get_functiondef(
        'public.emitir_invitacion_admin_interna(uuid,uuid,boolean)'::regprocedure
    )) <> '1447b79ee3ac3bf82835f1f2e0490bef' THEN
        RAISE EXCEPTION 'Cambio inesperado en emitir_invitacion_admin_interna';
    END IF;
END;
$verificacion$;


-- RESPALDO: public.validar_pago_admin(uuid,text,text,uuid)


CREATE OR REPLACE FUNCTION pg_temp.validar_pago_admin_ensayo(p_pago_id uuid, p_accion text, p_motivo text, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_pago pg_temp.pagos%ROWTYPE;
    v_registro pg_temp.registros%ROWTYPE;
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
    FROM pg_temp.pagos
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
    FROM pg_temp.registros
    WHERE id = v_pago.registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inscripción inexistente';
    END IF;

    -- PROTECCION MULTIEVENTO:
    -- Esta funcion original solo puede operar RADEVS.
    IF v_registro.evento_id IS DISTINCT FROM
       '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    THEN
        RAISE EXCEPTION
            'Operacion exclusiva de RADEVS';
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
        validado_por = p_admin_id,
        validado_at = now()
    WHERE id = p_pago_id;

    -- Conservar la auditoría.
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

        UPDATE pg_temp.registros
        SET estado = 'confirmado'
        WHERE id = v_pago.registro_id;

        -- Conservar el flujo de invitaciones existente.
        v_invitacion :=
            pg_temp.emitir_invitacion_admin_interna_ensayo(
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
$function$;

-- RESPALDO: public.autorizar_cortesia_admin(uuid,uuid)
CREATE OR REPLACE FUNCTION pg_temp.autorizar_cortesia_admin_ensayo(p_registro_id uuid, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro pg_temp.registros%ROWTYPE;
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
    FROM pg_temp.registros
    WHERE id = p_registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inscripción inexistente';
    END IF;

    -- PROTECCION MULTIEVENTO:
    -- Esta funcion original solo puede operar RADEVS.
    IF v_registro.evento_id IS DISTINCT FROM
       '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    THEN
        RAISE EXCEPTION
            'Operacion exclusiva de RADEVS';
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
        FROM pg_temp.pagos
        WHERE registro_id = p_registro_id
          AND estado = 'validado'
    ) THEN
        RAISE EXCEPTION
            'Esta inscripción ya tiene un pago validado';
    END IF;

    -- Autorizar cortesía y confirmar inscripción.
    UPDATE pg_temp.registros
    SET exento_pago = TRUE,
        estado = 'confirmado'
    WHERE id = p_registro_id;

    -- Conservar registro de auditoría.
    INSERT INTO pg_temp.auditoria (
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
        pg_temp.emitir_invitacion_admin_interna_ensayo(
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
$function$;

-- RESPALDO: public.recuperar_invitacion_admin(uuid,uuid,boolean)
CREATE OR REPLACE FUNCTION pg_temp.recuperar_invitacion_admin_ensayo(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro pg_temp.registros%ROWTYPE;
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
    FROM pg_temp.registros
    WHERE id = p_registro_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inscripción inexistente';
    END IF;

    -- PROTECCION MULTIEVENTO:
    -- Esta funcion original solo puede operar RADEVS.
    IF v_registro.evento_id IS DISTINCT FROM
       '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    THEN
        RAISE EXCEPTION
            'Operacion exclusiva de RADEVS';
    END IF;

    -- Prohibir reactivar registros cerrados.
    IF v_registro.estado IN ('cancelado', 'rechazado') THEN
        RAISE EXCEPTION
            'No se pueden recuperar invitaciones de inscripciones canceladas o rechazadas';
    END IF;

    IF NOT COALESCE(v_registro.exento_pago, false)
       AND NOT EXISTS (
           SELECT 1
           FROM pg_temp.pagos
           WHERE registro_id = p_registro_id
             AND estado = 'validado'
       )
    THEN
        RAISE EXCEPTION 'Sin pago validado ni cortesía';
    END IF;

    UPDATE pg_temp.registros
    SET estado = 'confirmado'
    WHERE id = p_registro_id;

    v_invitacion :=
        pg_temp.emitir_invitacion_admin_interna_ensayo(
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
$function$;

-- RESPALDO: pg_temp.emitir_invitacion_admin_interna_ensayo(uuid,uuid,boolean)
CREATE OR REPLACE FUNCTION pg_temp.emitir_invitacion_admin_interna_ensayo(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
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

    -- PROTECCION MULTIEVENTO:
    -- Esta funcion original solo puede operar RADEVS.
    IF v_registro.evento_id IS DISTINCT FROM
       '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    THEN
        RAISE EXCEPTION
            'Operacion exclusiva de RADEVS';
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
            FROM pg_temp.vault_bloqueado_ensayo
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

    v_vault_id := pg_temp.vault_bloqueado_ensayo(
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




-- ENSAYO POSITIVO RADEVS.
-- Todas las operaciones de escritura usan pg_temp.
-- Ninguna invitacion ficticia tiene token real.

DO $datos$
DECLARE
    v_admin uuid;
    v_evento uuid :=
        '43e67bda-d19d-4c0e-a639-e85f2d62f294';
BEGIN
    SELECT id INTO v_admin
    FROM public.usuarios
    WHERE rol = 'administrador'
      AND activo = TRUE
    LIMIT 1;

    IF v_admin IS NULL THEN
        RAISE EXCEPTION 'No existe administrador activo';
    END IF;

    PERFORM set_config(
        'app.ensayo.admin_id',
        v_admin::text,
        TRUE
    );

    -- Cinco inscripciones ficticias de RADEVS.
    INSERT INTO pg_temp.registros (
        id, evento_id, estado, exento_pago
    )
    VALUES
    ('11111111-1111-4111-8111-111111111111', v_evento, 'pendiente', FALSE),
    ('22222222-2222-4222-8222-222222222222', v_evento, 'pendiente', FALSE),
    ('33333333-3333-4333-8333-333333333333', v_evento, 'pendiente', FALSE),
    ('44444444-4444-4444-8444-444444444444', v_evento, 'confirmado', TRUE),
    ('55555555-5555-4555-8555-555555555555', v_evento, 'confirmado', TRUE);

    -- Dos pagos ficticios pendientes.
    INSERT INTO pg_temp.pagos (
        id, registro_id, importe, estado
    )
    VALUES
    (
        '66666666-6666-4666-8666-666666666666',
        '11111111-1111-4111-8111-111111111111',
        300,
        'pendiente'
    ),
    (
        '77777777-7777-4777-8777-777777777777',
        '22222222-2222-4222-8222-222222222222',
        300,
        'pendiente'
    );

    -- Cuatro invitaciones ficticias ya existentes.
    -- Sin token en Vault: nunca se consulta ni crea uno real.
    INSERT INTO pg_temp.invitaciones (
        id, registro_id, token_hash, token_vault_id,
        estado, emitida_por, emitida_at
    )
    VALUES
    (
        '81111111-1111-4111-8111-111111111111',
        '11111111-1111-4111-8111-111111111111',
        repeat('a', 64), NULL, 'activa', v_admin, now()
    ),
    (
        '83333333-3333-4333-8333-333333333333',
        '33333333-3333-4333-8333-333333333333',
        repeat('b', 64), NULL, 'activa', v_admin, now()
    ),
    (
        '84444444-4444-4444-8444-444444444444',
        '44444444-4444-4444-8444-444444444444',
        repeat('c', 64), NULL, 'activa', v_admin, now()
    ),
    (
        '85555555-5555-4555-8555-555555555555',
        '55555555-5555-4555-8555-555555555555',
        repeat('d', 64), NULL, 'activa', v_admin, now()
    );
END;
$datos$;

SET LOCAL ROLE authenticated;

DO $positivas$
DECLARE
    v_admin uuid :=
        current_setting('app.ensayo.admin_id')::uuid;
    v_resultado jsonb;
BEGIN
    -- 1. Aprobar pago RADEVS.
    v_resultado := pg_temp.validar_pago_admin_ensayo(
        '66666666-6666-4666-8666-666666666666',
        'aprobar', NULL, v_admin
    );

    IF v_resultado->>'estado' IS DISTINCT FROM 'validado'
       OR v_resultado->'invitacion'->>'ya_existia'
          IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Fallo aprobacion RADEVS';
    END IF;

    -- 2. Rechazar pago RADEVS.
    v_resultado := pg_temp.validar_pago_admin_ensayo(
        '77777777-7777-4777-8777-777777777777',
        'rechazar', 'Prueba de rechazo', v_admin
    );

    IF v_resultado->>'estado' IS DISTINCT FROM 'rechazado' THEN
        RAISE EXCEPTION 'Fallo rechazo RADEVS';
    END IF;

    -- 3. Autorizar cortesia RADEVS.
    v_resultado :=
        pg_temp.autorizar_cortesia_admin_ensayo(
            '33333333-3333-4333-8333-333333333333',
            v_admin
        );

    IF v_resultado->'invitacion'->>'ya_existia'
       IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Fallo cortesia RADEVS';
    END IF;

    -- 4. Recuperar invitacion RADEVS.
    v_resultado :=
        pg_temp.recuperar_invitacion_admin_ensayo(
            '44444444-4444-4444-8444-444444444444',
            v_admin,
            FALSE
        );

    IF v_resultado->'invitacion'->>'ya_existia'
       IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Fallo recuperacion RADEVS';
    END IF;

    -- 5. Consultar invitacion existente RADEVS.
    v_resultado :=
        pg_temp.emitir_invitacion_admin_interna_ensayo(
            '55555555-5555-4555-8555-555555555555',
            v_admin,
            FALSE
        );

    IF v_resultado->>'ya_existia'
       IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Fallo consulta QR RADEVS';
    END IF;

    IF v_resultado->>'token_qr' IS NOT NULL THEN
        RAISE EXCEPTION 'Token inesperado durante el ensayo';
    END IF;
END;
$positivas$;

RESET ROLE;

DO $verificar$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.pagos
        WHERE id = '66666666-6666-4666-8666-666666666666'
          AND estado = 'validado'
    ) THEN
        RAISE EXCEPTION 'No se aprobo el pago ficticio';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.pagos
        WHERE id = '77777777-7777-4777-8777-777777777777'
          AND estado = 'rechazado'
    ) THEN
        RAISE EXCEPTION 'No se rechazo el pago ficticio';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.registros
        WHERE id = '33333333-3333-4333-8333-333333333333'
          AND estado = 'confirmado'
          AND exento_pago = TRUE
    ) THEN
        RAISE EXCEPTION 'No se autorizo la cortesia ficticia';
    END IF;

    IF (SELECT count(*) FROM pg_temp.invitaciones) <> 4 THEN
        RAISE EXCEPTION 'Se modifico el total de invitaciones ficticias';
    END IF;

    IF (SELECT count(*) FROM pg_temp.auditoria) <> 3 THEN
        RAISE EXCEPTION 'Auditoria ficticia inesperada';
    END IF;
END;
$verificar$;

SELECT
    'APROBADO' AS resultado,
    'Cinco operaciones RADEVS correctas en tablas temporales'
        AS detalle;

ROLLBACK;