-- REVIEW ONLY. Requires separate explicit production approval.
-- Alternative to the consolidated migration: NEVER apply both routes.
BEGIN;
DO $stage_guard$ BEGIN
IF to_regprocedure('public.autorizar_cortesia_admin(uuid, uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.autorizar_cortesia_admin(uuid, uuid)'))) IS DISTINCT FROM '4d53670065863b2915614991c74cc2f6' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.autorizar_cortesia_admin(uuid, uuid)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.autorizar_cortesia_admin(uuid, uuid)'; END IF;
IF to_regprocedure('public.bandejas_admin_paginadas(text, integer, text, uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.bandejas_admin_paginadas(text, integer, text, uuid)'))) IS DISTINCT FROM '5ceb57ad2bcdf48b25be363597e31466' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.bandejas_admin_paginadas(text, integer, text, uuid)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.bandejas_admin_paginadas(text, integer, text, uuid)'; END IF;
IF to_regprocedure('public.consultar_qr_acceso(text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.consultar_qr_acceso(text)'))) IS DISTINCT FROM '810c49ef2297ac3e82fd3c168bd8b136' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.consultar_qr_acceso(text)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.consultar_qr_acceso(text)'; END IF;
IF to_regprocedure('public.emitir_invitacion_admin_interna(uuid, uuid, boolean)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.emitir_invitacion_admin_interna(uuid, uuid, boolean)'))) IS DISTINCT FROM '1447b79ee3ac3bf82835f1f2e0490bef' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.emitir_invitacion_admin_interna(uuid, uuid, boolean)')) IS DISTINCT FROM '{postgres=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.emitir_invitacion_admin_interna(uuid, uuid, boolean)'; END IF;
IF to_regprocedure('public.recuperar_invitacion_admin(uuid, uuid, boolean)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.recuperar_invitacion_admin(uuid, uuid, boolean)'))) IS DISTINCT FROM 'ca42ec72b3b0f2b482d6c3b8e4a760ca' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.recuperar_invitacion_admin(uuid, uuid, boolean)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.recuperar_invitacion_admin(uuid, uuid, boolean)'; END IF;
IF to_regprocedure('public.registrar_entrada_qr(text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.registrar_entrada_qr(text)'))) IS DISTINCT FROM '7ddff3b8899841bf5df7aa09cbe0c168' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.registrar_entrada_qr(text)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.registrar_entrada_qr(text)'; END IF;
IF to_regprocedure('public.validar_pago_admin(uuid, text, text, uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.validar_pago_admin(uuid, text, text, uuid)'))) IS DISTINCT FROM '1d9dda43554b32a8f75ecec77e17fcfe' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.validar_pago_admin(uuid, text, text, uuid)')) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.validar_pago_admin(uuid, text, text, uuid)'; END IF;
IF to_regprocedure('public.validar_pago_personal(uuid, text, text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.validar_pago_personal(uuid, text, text)'))) IS DISTINCT FROM 'd6f4bab8e43fa8a99dca3d2e1508d14e' OR (SELECT proacl::text FROM pg_proc WHERE oid=to_regprocedure('public.validar_pago_personal(uuid, text, text)')) IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Drift: public.validar_pago_personal(uuid, text, text)'; END IF;

END; $stage_guard$;
-- Source: sql/security/radevs_administracion_propuesta.sql
-- LOCAL ONLY. Requires explicit deployment approval. Preserve preflight hashes.
-- Evitar sobrescribir funciones que hayan cambiado.



-- RESPALDO: public.validar_pago_admin(uuid,text,text,uuid)
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
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        JOIN public.usuarios u ON u.id=ue.usuario_id
        WHERE ue.usuario_id = p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;
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
    SELECT p.*
    INTO v_pago
    FROM public.pagos p JOIN public.registros r ON r.id=p.registro_id
    WHERE p.id=p_pago_id AND r.evento_id='43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    FOR UPDATE OF p;

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
$function$;

-- RESPALDO: public.autorizar_cortesia_admin(uuid,uuid)
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
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        JOIN public.usuarios u ON u.id=ue.usuario_id
        WHERE ue.usuario_id = p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;
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
$function$;

-- RESPALDO: public.recuperar_invitacion_admin(uuid,uuid,boolean)
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
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        JOIN public.usuarios u ON u.id=ue.usuario_id
        WHERE ue.usuario_id = p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;
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
$function$;

-- RESPALDO: public.emitir_invitacion_admin_interna(uuid,uuid,boolean)
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
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        JOIN public.usuarios u ON u.id=ue.usuario_id
        WHERE ue.usuario_id = p_admin_id AND u.activo IS TRUE AND u.rol IN ('administrador','validador')
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;

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

REVOKE ALL ON FUNCTION public.validar_pago_admin(uuid,text,text,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.validar_pago_admin(uuid,text,text,uuid) TO service_role;
REVOKE ALL ON FUNCTION public.autorizar_cortesia_admin(uuid,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.autorizar_cortesia_admin(uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION public.recuperar_invitacion_admin(uuid,uuid,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recuperar_invitacion_admin(uuid,uuid,boolean) TO service_role;
REVOKE ALL ON FUNCTION public.emitir_invitacion_admin_interna(uuid,uuid,boolean) FROM PUBLIC, anon, authenticated, service_role;


-- Source: sql/security/radevs_personal_propuesta.sql
-- Cancelar si la funcion activa cambio desde el respaldo.


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

    IF NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;

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

    SELECT p.*
    INTO v_pago
    FROM public.pagos p JOIN public.registros r ON r.id=p.registro_id
    WHERE p.id=p_pago_id AND r.evento_id='43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    FOR UPDATE OF p;

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

REVOKE ALL ON FUNCTION public.validar_pago_personal(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validar_pago_personal(uuid,text,text) TO authenticated;

-- Source: sql/security/radevs_bandejas_propuesta.sql
-- LOCAL ONLY. Snapshot existing definition and ACL before approval.
-- EVENTO ANUAL AMOR 2026
-- Bandejas administrativas: busqueda, conteo y paginacion en PostgreSQL.
-- No cambia registros existentes ni habilita inscripciones publicas.
-- Instalar ANTES de desplegar la nueva Edge Function bandejas-admin.

CREATE OR REPLACE FUNCTION public.bandejas_admin_paginadas(
    p_tipo text,
    p_pagina integer,
    p_busqueda text,
    p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_evento_radevs CONSTANT uuid := '43e67bda-d19d-4c0e-a639-e85f2d62f294';
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

    -- Defensa adicional: la identidad debe coincidir si existe JWT SQL.
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;

    -- Un administrador global no obtiene acceso automatico a RADEVS.
    IF NOT EXISTS (
        SELECT 1
        FROM public.usuarios_eventos ue
        WHERE ue.usuario_id = p_admin_id
          AND ue.evento_id = v_evento_radevs
          AND ue.activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Administrador sin asignacion activa a RADEVS';
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
              AND r.evento_id = v_evento_radevs
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
            WHERE r.evento_id = v_evento_radevs
              AND (v_busqueda = '' OR strpos(
                lower(concat_ws(' ', m.nombres, m.apellidos,
                                r.folio, m.telefono_whatsapp, a.nombre)),
                v_busqueda
            ) > 0)
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
$function$;

-- Impedir llamadas directas desde el navegador.
REVOKE ALL ON FUNCTION public.bandejas_admin_paginadas(text,integer,text,uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bandejas_admin_paginadas(text,integer,text,uuid)
TO service_role;


-- Source: sql/chiapas/qr_legacy_compatibilidad.sql
-- PROPUESTA LOCAL. NO EJECUTAR EN PRODUCCION SIN PRUEBAS.
-- RADEV'S mantiene las firmas originales.
-- Todas las consultas y entradas pasan por validacion por evento.

CREATE OR REPLACE FUNCTION public.consultar_qr_acceso(
    p_token text
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $fn$
    SELECT public.consultar_qr_acceso_evento(
        p_token,
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    );
$fn$;

CREATE OR REPLACE FUNCTION public.registrar_entrada_qr(
    p_token text
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $fn$
    SELECT public.registrar_entrada_qr_evento(
        p_token,
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    );
$fn$;

REVOKE ALL
ON FUNCTION public.consultar_qr_acceso(text)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.registrar_entrada_qr(text)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.consultar_qr_acceso(text)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.registrar_entrada_qr(text)
TO authenticated;


COMMIT;
