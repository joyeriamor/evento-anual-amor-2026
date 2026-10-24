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



CREATE OR REPLACE FUNCTION pg_temp.validar_pago_admin_chiapas_ensayo(p_pago_id uuid, p_accion text, p_motivo text, p_admin_id uuid)
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

    -- Si existe identidad JWT, debe coincidir con el administrador.
    -- Las llamadas internas service_role deben validar el JWT en la API.
    IF auth.uid() IS NOT NULL
       AND auth.uid() IS DISTINCT FROM p_admin_id
    THEN
        RAISE EXCEPTION 'Identidad administrativa no coincide';
    END IF;
    -- Conservar la autorización administrativa existente.
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = TRUE
          AND EXISTS (
              SELECT 1
              FROM pg_temp.usuarios_eventos ue
              WHERE ue.usuario_id = p_admin_id
                AND ue.evento_id =
                    '3dc92160-79af-4bf7-b770-263038e88900'::uuid
                AND ue.activo IS TRUE
          )
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

    IF v_registro.evento_id IS DISTINCT FROM
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    THEN
        RAISE EXCEPTION 'Operacion exclusiva de Chiapas';
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
            pg_temp.emitir_invitacion_chiapas_ensayo(
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

CREATE OR REPLACE FUNCTION pg_temp.autorizar_cortesia_admin_chiapas_ensayo(p_registro_id uuid, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro pg_temp.registros%ROWTYPE;
    v_invitacion jsonb;
BEGIN

    -- Si existe identidad JWT, debe coincidir con el administrador.
    -- Las llamadas internas service_role deben validar el JWT en la API.
    IF auth.uid() IS NOT NULL
       AND auth.uid() IS DISTINCT FROM p_admin_id
    THEN
        RAISE EXCEPTION 'Identidad administrativa no coincide';
    END IF;
    -- Verificar administrador activo.
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = TRUE
          AND EXISTS (
              SELECT 1
              FROM pg_temp.usuarios_eventos ue
              WHERE ue.usuario_id = p_admin_id
                AND ue.evento_id =
                    '3dc92160-79af-4bf7-b770-263038e88900'::uuid
                AND ue.activo IS TRUE
          )
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

    IF v_registro.evento_id IS DISTINCT FROM
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    THEN
        RAISE EXCEPTION 'Operacion exclusiva de Chiapas';
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
        pg_temp.emitir_invitacion_chiapas_ensayo(
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

CREATE OR REPLACE FUNCTION pg_temp.recuperar_invitacion_admin_chiapas_ensayo(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro pg_temp.registros%ROWTYPE;
    v_invitacion jsonb;
BEGIN

    -- Si existe identidad JWT, debe coincidir con el administrador.
    -- Las llamadas internas service_role deben validar el JWT en la API.
    IF auth.uid() IS NOT NULL
       AND auth.uid() IS DISTINCT FROM p_admin_id
    THEN
        RAISE EXCEPTION 'Identidad administrativa no coincide';
    END IF;
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = true
          AND EXISTS (
              SELECT 1
              FROM pg_temp.usuarios_eventos ue
              WHERE ue.usuario_id = p_admin_id
                AND ue.evento_id =
                    '3dc92160-79af-4bf7-b770-263038e88900'::uuid
                AND ue.activo IS TRUE
          )
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

    IF v_registro.evento_id IS DISTINCT FROM
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    THEN
        RAISE EXCEPTION 'Operacion exclusiva de Chiapas';
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
        pg_temp.emitir_invitacion_chiapas_ensayo(
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

-- Nueve pruebas de autorizacion.
-- Todo se ejecuta con tablas temporales y ROLLBACK.

DO $versiones$
BEGIN
    IF md5(pg_get_functiondef(
        'public.validar_pago_admin(uuid,text,text,uuid)'::regprocedure
    )) <> '1d9dda43554b32a8f75ecec77e17fcfe'
    THEN
        RAISE EXCEPTION 'Cambio en validar_pago_admin original';
    END IF;

    IF md5(pg_get_functiondef(
        'public.autorizar_cortesia_admin(uuid,uuid)'::regprocedure
    )) <> '4d53670065863b2915614991c74cc2f6'
    THEN
        RAISE EXCEPTION 'Cambio en autorizar_cortesia_admin original';
    END IF;

    IF md5(pg_get_functiondef(
        'public.recuperar_invitacion_admin(uuid,uuid,boolean)'::regprocedure
    )) <> 'ca42ec72b3b0f2b482d6c3b8e4a760ca'
    THEN
        RAISE EXCEPTION 'Cambio en recuperar_invitacion_admin original';
    END IF;
END;
$versiones$;

INSERT INTO pg_temp.usuarios (id, nombre, rol, activo)
VALUES (
    'aa111111-1111-4111-8111-111111111111',
    'Admin ficticio Chiapas',
    'administrador',
    TRUE
);

INSERT INTO pg_temp.registros (
    id, evento_id, estado, exento_pago
)
VALUES
(
    'bb111111-1111-4111-8111-111111111111',
    '3dc92160-79af-4bf7-b770-263038e88900',
    'pendiente',
    FALSE
),
(
    'bb222222-2222-4222-8222-222222222222',
    '3dc92160-79af-4bf7-b770-263038e88900',
    'pendiente',
    FALSE
),
(
    'bb333333-3333-4333-8333-333333333333',
    '43e67bda-d19d-4c0e-a639-e85f2d62f294',
    'pendiente',
    FALSE
);

INSERT INTO pg_temp.pagos (
    id, registro_id, importe, estado
)
VALUES
(
    'cc111111-1111-4111-8111-111111111111',
    'bb111111-1111-4111-8111-111111111111',
    300,
    'pendiente'
),
(
    'cc333333-3333-4333-8333-333333333333',
    'bb333333-3333-4333-8333-333333333333',
    300,
    'pendiente'
);

SELECT set_config(
    'request.jwt.claim.sub',
    'aa111111-1111-4111-8111-111111111111',
    TRUE
);

SET LOCAL ROLE authenticated;

-- CASOS 1-3: administrador sin asignacion a Chiapas.
DO $sin_asignacion$
DECLARE
    v_operacion text;
    v_error text;
BEGIN
    FOREACH v_operacion IN ARRAY ARRAY[
        'pago', 'cortesia', 'recuperar'
    ] LOOP
        BEGIN
            CASE v_operacion
                WHEN 'pago' THEN
                    PERFORM pg_temp.validar_pago_admin_chiapas_ensayo(
                        'cc111111-1111-4111-8111-111111111111',
                        'aprobar',
                        NULL,
                        'aa111111-1111-4111-8111-111111111111'
                    );
                WHEN 'cortesia' THEN
                    PERFORM pg_temp.autorizar_cortesia_admin_chiapas_ensayo(
                        'bb222222-2222-4222-8222-222222222222',
                        'aa111111-1111-4111-8111-111111111111'
                    );
                WHEN 'recuperar' THEN
                    PERFORM pg_temp.recuperar_invitacion_admin_chiapas_ensayo(
                        'bb111111-1111-4111-8111-111111111111',
                        'aa111111-1111-4111-8111-111111111111',
                        FALSE
                    );
            END CASE;

            RAISE EXCEPTION 'OPERACION PERMITIDA SIN ASIGNACION';

        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

            IF v_error <> 'Administrador no autorizado' THEN
                RAISE EXCEPTION
                    'Fallo sin asignacion (%): %',
                    v_operacion, v_error;
            END IF;
        END;
    END LOOP;
END;
$sin_asignacion$;

RESET ROLE;

-- Asignacion exclusivamente ficticia.
INSERT INTO pg_temp.usuarios_eventos (
    usuario_id, evento_id, activo
)
VALUES (
    'aa111111-1111-4111-8111-111111111111',
    '3dc92160-79af-4bf7-b770-263038e88900',
    TRUE
);

SET LOCAL ROLE authenticated;

-- CASOS 4-6: operaciones cruzadas sobre RADEV'S.
DO $eventos_cruzados$
DECLARE
    v_operacion text;
    v_error text;
BEGIN
    FOREACH v_operacion IN ARRAY ARRAY[
        'pago', 'cortesia', 'recuperar'
    ] LOOP
        BEGIN
            CASE v_operacion
                WHEN 'pago' THEN
                    PERFORM pg_temp.validar_pago_admin_chiapas_ensayo(
                        'cc333333-3333-4333-8333-333333333333',
                        'aprobar',
                        NULL,
                        'aa111111-1111-4111-8111-111111111111'
                    );
                WHEN 'cortesia' THEN
                    PERFORM pg_temp.autorizar_cortesia_admin_chiapas_ensayo(
                        'bb333333-3333-4333-8333-333333333333',
                        'aa111111-1111-4111-8111-111111111111'
                    );
                WHEN 'recuperar' THEN
                    PERFORM pg_temp.recuperar_invitacion_admin_chiapas_ensayo(
                        'bb333333-3333-4333-8333-333333333333',
                        'aa111111-1111-4111-8111-111111111111',
                        FALSE
                    );
            END CASE;

            RAISE EXCEPTION 'OPERACION CRUZADA PERMITIDA';

        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

            IF v_error <> 'Operacion exclusiva de Chiapas' THEN
                RAISE EXCEPTION
                    'Fallo entre eventos (%): %',
                    v_operacion, v_error;
            END IF;
        END;
    END LOOP;
END;
$eventos_cruzados$;

-- CASOS 7-9: JWT distinto del administrador indicado.
DO $identidad_incorrecta$
DECLARE
    v_operacion text;
    v_error text;
BEGIN
    PERFORM set_config(
        'request.jwt.claim.sub',
        'dd111111-1111-4111-8111-111111111111',
        TRUE
    );

    FOREACH v_operacion IN ARRAY ARRAY[
        'pago', 'cortesia', 'recuperar'
    ] LOOP
        BEGIN
            CASE v_operacion
                WHEN 'pago' THEN
                    PERFORM pg_temp.validar_pago_admin_chiapas_ensayo(
                        'cc111111-1111-4111-8111-111111111111',
                        'aprobar',
                        NULL,
                        'aa111111-1111-4111-8111-111111111111'
                    );
                WHEN 'cortesia' THEN
                    PERFORM pg_temp.autorizar_cortesia_admin_chiapas_ensayo(
                        'bb222222-2222-4222-8222-222222222222',
                        'aa111111-1111-4111-8111-111111111111'
                    );
                WHEN 'recuperar' THEN
                    PERFORM pg_temp.recuperar_invitacion_admin_chiapas_ensayo(
                        'bb111111-1111-4111-8111-111111111111',
                        'aa111111-1111-4111-8111-111111111111',
                        FALSE
                    );
            END CASE;

            RAISE EXCEPTION 'IDENTIDAD INCORRECTA PERMITIDA';

        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

            IF v_error <> 'Identidad administrativa no coincide' THEN
                RAISE EXCEPTION
                    'Fallo de identidad (%): %',
                    v_operacion, v_error;
            END IF;
        END;
    END LOOP;
END;
$identidad_incorrecta$;

RESET ROLE;

-- Confirmar que los nueve rechazos no modificaron datos.
DO $comprobacion$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_temp.pagos
        WHERE estado <> 'pendiente'
    ) THEN
        RAISE EXCEPTION 'Se modifico algun pago ficticio';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_temp.registros
        WHERE estado <> 'pendiente'
           OR exento_pago IS TRUE
    ) THEN
        RAISE EXCEPTION 'Se modifico alguna inscripcion ficticia';
    END IF;

    IF (SELECT count(*) FROM pg_temp.invitaciones) <> 0
       OR (SELECT count(*) FROM pg_temp.auditoria) <> 0
       OR (SELECT count(*) FROM pg_temp.vault_decrypted_ensayo) <> 0
    THEN
        RAISE EXCEPTION 'Un rechazo genero QR o auditoria';
    END IF;
END;
$comprobacion$;

SELECT
    'APROBADO' AS resultado,
    '9 bloqueos administrativos correctos, sin modificar datos'
        AS detalle;

ROLLBACK;