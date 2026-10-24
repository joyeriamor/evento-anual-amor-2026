BEGIN;

-- Generador independiente de Chiapas.
-- Preparado para revision y ensayos.
-- NO ejecutar en produccion hasta completar las pruebas.

DO $control$
BEGIN
    IF md5(pg_get_functiondef(
        'public.emitir_invitacion_admin_interna(uuid,uuid,boolean)'::regprocedure
    )) <> '1447b79ee3ac3bf82835f1f2e0490bef'
    THEN
        RAISE EXCEPTION
            'El generador original cambio inesperadamente';
    END IF;

    IF to_regprocedure(
        'public.emitir_invitacion_chiapas_interna(uuid,uuid,boolean)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION
            'El generador de Chiapas ya existe';
    END IF;
END;
$control$;

CREATE OR REPLACE FUNCTION public.emitir_invitacion_chiapas_interna(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
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
        JOIN public.usuarios_eventos ue
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

$function$;

-- Funcion interna: sin ejecucion directa desde navegador.
REVOKE ALL ON FUNCTION
    public.emitir_invitacion_chiapas_interna(uuid,uuid,boolean)
FROM PUBLIC, anon, authenticated, service_role;

COMMIT;