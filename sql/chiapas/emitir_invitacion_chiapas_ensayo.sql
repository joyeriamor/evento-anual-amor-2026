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

CREATE TEMP TABLE registros
AS SELECT * FROM public.registros WHERE FALSE;

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
        FROM public.usuarios u
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

DO $datos$
DECLARE
    v_admin uuid;
BEGIN
    SELECT id INTO v_admin
    FROM public.usuarios
    WHERE rol = 'administrador'
      AND activo IS TRUE
    LIMIT 1;

    IF v_admin IS NULL THEN
        RAISE EXCEPTION 'No existe administrador activo';
    END IF;

    PERFORM set_config(
        'app.ensayo.admin_id',
        v_admin::text,
        TRUE
    );

    -- Registro de RADEV'S: debe rechazarse.
    INSERT INTO pg_temp.registros (id, evento_id, estado)
    VALUES (
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        '43e67bda-d19d-4c0e-a639-e85f2d62f294',
        'confirmado'
    );

    -- Tres registros ficticios de Chiapas.
    INSERT INTO pg_temp.registros (id, evento_id, estado)
    VALUES
    (
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        '3dc92160-79af-4bf7-b770-263038e88900',
        'confirmado'
    ),
    (
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        '3dc92160-79af-4bf7-b770-263038e88900',
        'confirmado'
    ),
    (
        'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        '3dc92160-79af-4bf7-b770-263038e88900',
        'confirmado'
    );

    -- Token ficticio de una invitacion existente.
    INSERT INTO pg_temp.vault_decrypted_ensayo (
        id, decrypted_secret
    )
    VALUES (
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
        'qr-demo-inicial-chiapas'
    );

    INSERT INTO pg_temp.invitaciones (
        id, registro_id, token_hash,
        token_vault_id, estado, emitida_por, emitida_at
    )
    VALUES (
        'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        encode(
            sha256(convert_to('qr-demo-inicial-chiapas', 'UTF8')),
            'hex'
        ),
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
        'activa',
        v_admin,
        now()
    );
END;
$datos$;

SET LOCAL ROLE authenticated;

DO $pruebas$
DECLARE
    v_admin uuid :=
        current_setting('app.ensayo.admin_id')::uuid;
    v_resultado jsonb;
    v_error text;
    v_token_original text;
    v_token_nuevo text;
BEGIN
    -- PRUEBA 1: registro de RADEV'S rechazado.
    BEGIN
        PERFORM pg_temp.emitir_invitacion_chiapas_ensayo(
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            v_admin,
            FALSE
        );

        RAISE EXCEPTION 'RADEV S fue aceptado indebidamente';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

        IF v_error <> 'Operacion exclusiva de Chiapas' THEN
            RAISE EXCEPTION 'Fallo aislamiento RADEVS: %', v_error;
        END IF;
    END;

    -- PRUEBA 2: operador sin asignacion rechazado.
    BEGIN
        PERFORM pg_temp.emitir_invitacion_chiapas_ensayo(
            'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            v_admin,
            FALSE
        );

        RAISE EXCEPTION 'Operador sin asignacion aceptado';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;

        IF v_error <> 'Operador de Chiapas no autorizado' THEN
            RAISE EXCEPTION 'Fallo autorizacion: %', v_error;
        END IF;
    END;

    -- Asignacion SOLO temporal para pruebas positivas.
    INSERT INTO pg_temp.usuarios_eventos (
        usuario_id, evento_id, activo
    )
    VALUES (
        v_admin,
        '3dc92160-79af-4bf7-b770-263038e88900',
        TRUE
    );

    -- PRUEBA 3: recuperar QR existente.
    v_resultado :=
        pg_temp.emitir_invitacion_chiapas_ensayo(
            'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            v_admin,
            FALSE
        );

    IF v_resultado->>'ya_existia' <> 'true'
       OR v_resultado->>'token_qr'
          IS DISTINCT FROM 'qr-demo-inicial-chiapas'
    THEN
        RAISE EXCEPTION 'Fallo recuperacion QR';
    END IF;

    -- PRUEBA 4: crear QR nuevo.
    v_resultado :=
        pg_temp.emitir_invitacion_chiapas_ensayo(
            'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            v_admin,
            FALSE
        );

    v_token_original := v_resultado->>'token_qr';

    IF v_resultado->>'ya_existia' <> 'false'
       OR length(coalesce(v_token_original, '')) <> 64
    THEN
        RAISE EXCEPTION 'Fallo creacion QR';
    END IF;

    -- PRUEBA 5: recuperar el QR recien creado.
    v_resultado :=
        pg_temp.emitir_invitacion_chiapas_ensayo(
            'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            v_admin,
            FALSE
        );

    IF v_resultado->>'ya_existia' <> 'true'
       OR v_resultado->>'token_qr'
          IS DISTINCT FROM v_token_original
    THEN
        RAISE EXCEPTION 'No se recupero el mismo QR';
    END IF;

    -- PRUEBA 6: reemitir QR.
    v_resultado :=
        pg_temp.emitir_invitacion_chiapas_ensayo(
            'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            v_admin,
            TRUE
        );

    v_token_nuevo := v_resultado->>'token_qr';

    IF v_resultado->>'ya_existia' <> 'false'
       OR length(coalesce(v_token_nuevo, '')) <> 64
       OR v_token_nuevo = v_token_original
    THEN
        RAISE EXCEPTION 'Fallo reemision QR';
    END IF;
END;
$pruebas$;

RESET ROLE;

DO $verificar$
BEGIN
    -- Dos invitaciones del registro nuevo:
    -- una revocada y otra emitida.
    IF (
        SELECT COUNT(*)
        FROM pg_temp.invitaciones
        WHERE registro_id =
            'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
    ) <> 2 THEN
        RAISE EXCEPTION 'Cantidad de invitaciones incorrecta';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM pg_temp.invitaciones
        WHERE registro_id =
            'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
          AND estado = 'revocada'
    ) <> 1 THEN
        RAISE EXCEPTION 'QR anterior no revocado';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM pg_temp.invitaciones
        WHERE registro_id =
            'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
          AND estado = 'emitida'
    ) <> 1 THEN
        RAISE EXCEPTION 'QR nuevo no emitido';
    END IF;

    -- Una clave inicial y dos claves creadas por el simulador.
    IF (SELECT COUNT(*) FROM pg_temp.vault_decrypted_ensayo) <> 3 THEN
        RAISE EXCEPTION 'Vault ficticio inconsistente';
    END IF;

    -- Crear y reemitir generan dos registros de auditoria.
    IF (SELECT COUNT(*) FROM pg_temp.auditoria) <> 2 THEN
        RAISE EXCEPTION 'Auditoria ficticia inconsistente';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM pg_temp.usuarios_eventos
    ) <> 1 THEN
        RAISE EXCEPTION 'Asignaciones ficticias inconsistentes';
    END IF;
END;
$verificar$;

SELECT
    'APROBADO' AS resultado,
    '2 bloqueos y 4 flujos QR correctos con Vault ficticio'
        AS detalle;

ROLLBACK;