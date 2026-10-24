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

-- Cinco operaciones positivas con datos ficticios.
-- Ningun dato de esta prueba debe persistir.

INSERT INTO pg_temp.usuarios (id, nombre, rol, activo)
VALUES (
    'aa111111-1111-4111-8111-111111111111',
    'Administrador ficticio Chiapas',
    'administrador',
    TRUE
);

INSERT INTO pg_temp.usuarios_eventos (
    usuario_id, evento_id, activo
)
VALUES (
    'aa111111-1111-4111-8111-111111111111',
    '3dc92160-79af-4bf7-b770-263038e88900',
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
    '3dc92160-79af-4bf7-b770-263038e88900',
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
    'cc222222-2222-4222-8222-222222222222',
    'bb222222-2222-4222-8222-222222222222',
    300,
    'pendiente'
);

SELECT set_config(
    'request.jwt.claim.sub',
    'aa111111-1111-4111-8111-111111111111',
    TRUE
);

SET LOCAL ROLE authenticated;

DO $positivas$
DECLARE
    v_admin CONSTANT uuid :=
        'aa111111-1111-4111-8111-111111111111';

    v_pago_aprobado jsonb;
    v_pago_rechazado jsonb;
    v_cortesia jsonb;
    v_recuperada jsonb;
    v_reemitida jsonb;

    v_token_original text;
    v_token_nuevo text;
BEGIN
    -- CASO 1: aprobar pago y generar su invitacion.
    v_pago_aprobado :=
        pg_temp.validar_pago_admin_chiapas_ensayo(
            'cc111111-1111-4111-8111-111111111111',
            'aprobar',
            NULL,
            v_admin
        );

    IF v_pago_aprobado->>'estado' IS DISTINCT FROM 'validado'
       OR v_pago_aprobado->'invitacion'->>'ya_existia'
          IS DISTINCT FROM 'false'
       OR length(coalesce(
           v_pago_aprobado->'invitacion'->>'token_qr', ''
       )) <> 64
    THEN
        RAISE EXCEPTION 'Fallo aprobacion administrativa';
    END IF;

    -- CASO 2: rechazar otro pago sin emitir invitacion.
    v_pago_rechazado :=
        pg_temp.validar_pago_admin_chiapas_ensayo(
            'cc222222-2222-4222-8222-222222222222',
            'rechazar',
            'Comprobante de prueba invalido',
            v_admin
        );

    IF v_pago_rechazado->>'estado' IS DISTINCT FROM 'rechazado'
       OR v_pago_rechazado->'invitacion'
          IS DISTINCT FROM 'null'::jsonb
    THEN
        RAISE EXCEPTION 'Fallo rechazo administrativo';
    END IF;

    -- CASO 3: autorizar cortesia y emitir QR.
    v_cortesia :=
        pg_temp.autorizar_cortesia_admin_chiapas_ensayo(
            'bb333333-3333-4333-8333-333333333333',
            v_admin
        );

    v_token_original :=
        v_cortesia->'invitacion'->>'token_qr';

    IF v_cortesia->>'ok' IS DISTINCT FROM 'true'
       OR v_cortesia->'invitacion'->>'ya_existia'
          IS DISTINCT FROM 'false'
       OR length(coalesce(v_token_original, '')) <> 64
    THEN
        RAISE EXCEPTION 'Fallo autorizacion de cortesia';
    END IF;

    -- CASO 4: recuperar el mismo QR sin crear otro.
    v_recuperada :=
        pg_temp.recuperar_invitacion_admin_chiapas_ensayo(
            'bb333333-3333-4333-8333-333333333333',
            v_admin,
            FALSE
        );

    IF v_recuperada->'invitacion'->>'ya_existia'
          IS DISTINCT FROM 'true'
       OR v_recuperada->'invitacion'->>'token_qr'
          IS DISTINCT FROM v_token_original
       OR v_recuperada->'invitacion'->>'invitacion_id'
          IS DISTINCT FROM
             v_cortesia->'invitacion'->>'invitacion_id'
    THEN
        RAISE EXCEPTION 'No se recupero el QR original';
    END IF;

    -- CASO 5: reemitir un QR distinto.
    v_reemitida :=
        pg_temp.recuperar_invitacion_admin_chiapas_ensayo(
            'bb333333-3333-4333-8333-333333333333',
            v_admin,
            TRUE
        );

    v_token_nuevo :=
        v_reemitida->'invitacion'->>'token_qr';

    IF v_reemitida->'invitacion'->>'ya_existia'
          IS DISTINCT FROM 'false'
       OR length(coalesce(v_token_nuevo, '')) <> 64
       OR v_token_nuevo IS NOT DISTINCT FROM v_token_original
       OR v_reemitida->'invitacion'->>'invitacion_id'
          IS NOT DISTINCT FROM
             v_cortesia->'invitacion'->>'invitacion_id'
    THEN
        RAISE EXCEPTION 'Fallo reemision del QR';
    END IF;
END;
$positivas$;

RESET ROLE;

DO $comprobacion$
BEGIN
    -- Pago aprobado y registro confirmado.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_temp.pagos
        WHERE id = 'cc111111-1111-4111-8111-111111111111'
          AND estado = 'validado'
    )
    OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.registros
        WHERE id = 'bb111111-1111-4111-8111-111111111111'
          AND estado = 'confirmado'
          AND exento_pago IS FALSE
    ) THEN
        RAISE EXCEPTION 'Estado incorrecto del pago aprobado';
    END IF;

    -- Pago rechazado sin confirmar su inscripcion.
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.pagos
        WHERE id = 'cc222222-2222-4222-8222-222222222222'
          AND estado = 'rechazado'
    )
    OR NOT EXISTS (
        SELECT 1 FROM pg_temp.registros
        WHERE id = 'bb222222-2222-4222-8222-222222222222'
          AND estado = 'pendiente'
    ) THEN
        RAISE EXCEPTION 'Estado incorrecto del pago rechazado';
    END IF;

    -- Cortesia confirmada.
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.registros
        WHERE id = 'bb333333-3333-4333-8333-333333333333'
          AND estado = 'confirmado'
          AND exento_pago IS TRUE
    ) THEN
        RAISE EXCEPTION 'Cortesia no confirmada';
    END IF;

    -- Tres invitaciones: pago, cortesia anterior, cortesia nueva.
    IF (SELECT count(*) FROM pg_temp.invitaciones) <> 3
       OR (SELECT count(*) FROM pg_temp.invitaciones
           WHERE estado = 'emitida') <> 2
       OR (SELECT count(*) FROM pg_temp.invitaciones
           WHERE estado = 'revocada') <> 1
    THEN
        RAISE EXCEPTION 'Estados de invitaciones incorrectos';
    END IF;

    -- El QR antiguo de la cortesia esta revocado.
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.invitaciones
        WHERE registro_id =
            'bb333333-3333-4333-8333-333333333333'
          AND estado = 'revocada'
          AND revocada_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'No se revoco el QR anterior';
    END IF;

    IF (SELECT count(*) FROM pg_temp.vault_decrypted_ensayo) <> 3
    THEN
        RAISE EXCEPTION 'Vault ficticio inconsistente';
    END IF;

    -- Verificar hashes de todos los QR emitidos.
    IF (
        SELECT count(*)
        FROM pg_temp.invitaciones i
        JOIN pg_temp.vault_decrypted_ensayo v
          ON v.id = i.token_vault_id
        WHERE i.token_hash = encode(
            sha256(convert_to(v.decrypted_secret, 'UTF8')),
            'hex'
        )
    ) <> 3 THEN
        RAISE EXCEPTION 'Hash o referencia Vault incorrecta';
    END IF;

    -- Dos auditorias de pagos, dos emisiones,
    -- una cortesia y una reemision.
    IF (SELECT count(*) FROM pg_temp.auditoria) <> 6
       OR (SELECT count(*) FROM pg_temp.auditoria
           WHERE accion = 'aprobar_pago') <> 1
       OR (SELECT count(*) FROM pg_temp.auditoria
           WHERE accion = 'rechazar_pago') <> 1
       OR (SELECT count(*) FROM pg_temp.auditoria
           WHERE accion = 'autorizar_cortesia') <> 1
       OR (SELECT count(*) FROM pg_temp.auditoria
           WHERE accion = 'emitir_invitacion') <> 2
       OR (SELECT count(*) FROM pg_temp.auditoria
           WHERE accion = 'reemitir_invitacion') <> 1
    THEN
        RAISE EXCEPTION 'Auditoria administrativa incorrecta';
    END IF;
END;
$comprobacion$;

SELECT
    'APROBADO' AS resultado,
    '5 flujos administrativos correctos con QR y Vault ficticios'
        AS detalle;

ROLLBACK;