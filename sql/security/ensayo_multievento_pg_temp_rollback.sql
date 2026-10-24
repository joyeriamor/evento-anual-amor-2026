-- ENSAYO REAL DE POSTGRESQL: SOLO pg_temp + datos ficticios + ROLLBACK.
-- NO aplica la migración, modifica funciones public, usa filas reales, Auth ni Storage.
-- Vault se sustituye por una tabla TEMPORAL; no se prueba Supabase Vault.
BEGIN;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
CREATE TEMP TABLE usuarios (LIKE public.usuarios INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE usuarios_eventos (LIKE public.usuarios_eventos INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE eventos (LIKE public.eventos INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE configuracion_cupo_evento (LIKE public.configuracion_cupo_evento INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE asesores (LIKE public.asesores INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE promotoras (LIKE public.promotoras INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE registros (LIKE public.registros INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE pagos (LIKE public.pagos INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE invitaciones (LIKE public.invitaciones INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE accesos (LIKE public.accesos INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE auditoria (LIKE public.auditoria INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE resultados_ensayo(caso text PRIMARY KEY,aprobado boolean NOT NULL) ON COMMIT DROP;
CREATE TEMP TABLE secretos_ensayo(id uuid PRIMARY KEY,decrypted_secret text NOT NULL) ON COMMIT DROP;
CREATE TEMP TABLE catalogo_antes_ensayo ON COMMIT DROP AS
 SELECT md5(string_agg(p.oid::text||pg_get_functiondef(p.oid)||coalesce(p.proacl::text,''),'|' ORDER BY p.oid)) huella
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f';
CREATE FUNCTION pg_temp.verificar_ensayo(p_caso text,p_ok boolean) RETURNS void LANGUAGE plpgsql AS $verify$
BEGIN
 IF p_ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO: %',p_caso; END IF;
 INSERT INTO pg_temp.resultados_ensayo VALUES(p_caso,true);
END;
$verify$;
CREATE FUNCTION pg_temp.crear_secreto_ensayo(text,text,text,uuid) RETURNS uuid LANGUAGE plpgsql AS $secret$
DECLARE v_id uuid:=gen_random_uuid(); BEGIN
 INSERT INTO pg_temp.secretos_ensayo VALUES(v_id,$1); RETURN v_id;
END;
$secret$;

-- Copia del cuerpo final: validar_pago_admin
CREATE OR REPLACE FUNCTION pg_temp.validar_pago_admin(p_pago_id uuid, p_accion text, p_motivo text, p_admin_id uuid)
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
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.usuarios_eventos ue
        JOIN pg_temp.usuarios u ON u.id=ue.usuario_id
        WHERE ue.usuario_id = p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;
    -- Conservar la autorización administrativa existente.
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios
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
    FROM pg_temp.pagos p JOIN pg_temp.registros r ON r.id=p.registro_id
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
            pg_temp.emitir_invitacion_admin_interna(
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

-- Copia del cuerpo final: validar_pago_admin_chiapas
CREATE OR REPLACE FUNCTION pg_temp.validar_pago_admin_chiapas(p_pago_id uuid, p_accion text, p_motivo text, p_admin_id uuid)
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
    SELECT p.*
    INTO v_pago
    FROM pg_temp.pagos p JOIN pg_temp.registros r ON r.id=p.registro_id
    WHERE p.id=p_pago_id AND r.evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid
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
            pg_temp.emitir_invitacion_chiapas_interna(
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

-- Copia del cuerpo final: validar_pago_personal
CREATE OR REPLACE FUNCTION pg_temp.validar_pago_personal(p_pago_id uuid, p_accion text, p_motivo text DEFAULT NULL::text)
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

    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.usuarios_eventos ue
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
    FROM pg_temp.pagos p JOIN pg_temp.registros r ON r.id=p.registro_id
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
    FROM pg_temp.registros
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
            pg_temp.emitir_invitacion_admin_interna(
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

-- Copia del cuerpo final: validar_pago_personal_chiapas
CREATE OR REPLACE FUNCTION pg_temp.validar_pago_personal_chiapas(p_pago_id uuid, p_accion text, p_motivo text DEFAULT NULL::text)
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

    SELECT p.*
    INTO v_pago
    FROM pg_temp.pagos p JOIN pg_temp.registros r ON r.id=p.registro_id
    WHERE p.id=p_pago_id AND r.evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid
    FOR UPDATE OF p;

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
            pg_temp.emitir_invitacion_chiapas_interna(
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

-- Copia del cuerpo final: autorizar_cortesia_admin
CREATE OR REPLACE FUNCTION pg_temp.autorizar_cortesia_admin(p_registro_id uuid, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro pg_temp.registros%ROWTYPE;
    v_invitacion jsonb;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.usuarios_eventos ue
        JOIN pg_temp.usuarios u ON u.id=ue.usuario_id
        WHERE ue.usuario_id = p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;
    -- Verificar administrador activo.
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios
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
        pg_temp.emitir_invitacion_admin_interna(
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

-- Copia del cuerpo final: autorizar_cortesia_admin_chiapas
CREATE OR REPLACE FUNCTION pg_temp.autorizar_cortesia_admin_chiapas(p_registro_id uuid, p_admin_id uuid)
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
        pg_temp.emitir_invitacion_chiapas_interna(
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

-- Copia del cuerpo final: recuperar_invitacion_admin
CREATE OR REPLACE FUNCTION pg_temp.recuperar_invitacion_admin(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro pg_temp.registros%ROWTYPE;
    v_invitacion jsonb;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.usuarios_eventos ue
        JOIN pg_temp.usuarios u ON u.id=ue.usuario_id
        WHERE ue.usuario_id = p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;
    IF p_admin_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios
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
        pg_temp.emitir_invitacion_admin_interna(
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

-- Copia del cuerpo final: recuperar_invitacion_admin_chiapas
CREATE OR REPLACE FUNCTION pg_temp.recuperar_invitacion_admin_chiapas(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
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
        pg_temp.emitir_invitacion_chiapas_interna(
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

-- Copia del cuerpo final: emitir_invitacion_admin_interna
CREATE OR REPLACE FUNCTION pg_temp.emitir_invitacion_admin_interna(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
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
    IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
        RAISE EXCEPTION 'Identidad administrativa incorrecta';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.usuarios_eventos ue
        JOIN pg_temp.usuarios u ON u.id=ue.usuario_id
        WHERE ue.usuario_id = p_admin_id AND u.activo IS TRUE AND u.rol IN ('administrador','validador')
          AND ue.evento_id = '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
          AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa RADEVS'; END IF;

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
            FROM pg_temp.secretos_ensayo
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

$function$
;

-- Copia del cuerpo final: emitir_invitacion_chiapas_interna
CREATE OR REPLACE FUNCTION pg_temp.emitir_invitacion_chiapas_interna(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
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
            FROM pg_temp.secretos_ensayo
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

$function$
;

-- Copia del cuerpo final: consultar_qr_acceso_evento
CREATE OR REPLACE FUNCTION pg_temp.consultar_qr_acceso_evento(p_token text, p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_operador uuid := auth.uid();
    v_invitacion pg_temp.invitaciones%ROWTYPE;
    v_registro pg_temp.registros%ROWTYPE;
    v_ingreso timestamptz;
BEGIN

    IF p_evento_id IS NULL OR p_evento_id NOT IN (
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_temp.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador AND ue.evento_id = p_evento_id AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa al evento'; END IF;
    -- Solo administrador y acceso activos.
    IF v_operador IS NULL OR NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios
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
    FROM pg_temp.invitaciones
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
    FROM pg_temp.registros
    WHERE id = v_invitacion.registro_id AND evento_id = p_evento_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'no_confirmado'
        );
    END IF;

    SELECT MIN(a.ingresado_at)
    INTO v_ingreso
    FROM pg_temp.accesos a
    JOIN pg_temp.invitaciones i
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
                     FROM pg_temp.pagos p
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

-- Copia del cuerpo final: consultar_qr_acceso
CREATE OR REPLACE FUNCTION pg_temp.consultar_qr_acceso(p_token text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
    SELECT pg_temp.consultar_qr_acceso_evento(
        p_token,
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    );
$function$
;

-- Copia del cuerpo final: registrar_entrada_qr_evento
CREATE OR REPLACE FUNCTION pg_temp.registrar_entrada_qr_evento(p_token text, p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_operador uuid := auth.uid();
  v_invitacion pg_temp.invitaciones%ROWTYPE;
  v_registro pg_temp.registros%ROWTYPE;
  v_ingreso timestamptz;
  v_acceso_id uuid;
BEGIN

    IF p_evento_id IS NULL OR p_evento_id NOT IN (
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_temp.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador AND ue.evento_id = p_evento_id AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa al evento'; END IF;
  IF v_operador IS NULL OR NOT EXISTS (
    SELECT 1 FROM pg_temp.usuarios
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
  FROM pg_temp.invitaciones
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
  FROM pg_temp.registros
  WHERE id = v_invitacion.registro_id AND evento_id = p_evento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'estado', 'qr_invalido');
  END IF;
  -- Refresh invitation AFTER acquiring the registration lock: a concurrent reissue
  -- must not let a revoked QR enter using a stale pre-lock snapshot.
  SELECT * INTO v_invitacion FROM pg_temp.invitaciones
  WHERE id = v_invitacion.id FOR UPDATE;

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
       FROM pg_temp.pagos
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
  FROM pg_temp.accesos a
  JOIN pg_temp.invitaciones i
    ON i.id = a.invitacion_id
  WHERE i.registro_id = v_registro.id;

  IF v_ingreso IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'estado', 'ya_ingreso',
      'ingresado_at', v_ingreso
    );
  END IF;

  INSERT INTO pg_temp.accesos (
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

-- Copia del cuerpo final: registrar_entrada_qr
CREATE OR REPLACE FUNCTION pg_temp.registrar_entrada_qr(p_token text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
    SELECT pg_temp.registrar_entrada_qr_evento(
        p_token,
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
    );
$function$
;

-- Copia del cuerpo final: bandejas_admin_paginadas
CREATE OR REPLACE FUNCTION pg_temp.bandejas_admin_paginadas(p_tipo text, p_pagina integer, p_busqueda text, p_admin_id uuid)
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
        FROM pg_temp.usuarios
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
        FROM pg_temp.usuarios_eventos ue
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
            FROM pg_temp.pagos p
            JOIN pg_temp.registros r ON r.id = p.registro_id
            LEFT JOIN pg_temp.promotoras m ON m.id = r.promotora_id
            LEFT JOIN pg_temp.asesores a ON a.id = r.asesor_id
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
            FROM pg_temp.registros r
            LEFT JOIN pg_temp.promotoras m ON m.id = r.promotora_id
            LEFT JOIN pg_temp.asesores a ON a.id = r.asesor_id
            LEFT JOIN LATERAL (
                SELECT iv.id, iv.estado, iv.emitida_at
                FROM pg_temp.invitaciones iv
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
$function$
;

-- Copia del cuerpo final: bandejas_admin_chiapas_paginadas
CREATE OR REPLACE FUNCTION pg_temp.bandejas_admin_chiapas_paginadas(p_tipo text, p_pagina integer, p_busqueda text, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_evento_chiapas CONSTANT uuid := '3dc92160-79af-4bf7-b770-263038e88900';
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
        FROM pg_temp.usuarios
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

    -- Un administrador global no obtiene acceso automatico a Chiapas.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_temp.usuarios_eventos ue
        WHERE ue.usuario_id = p_admin_id
          AND ue.evento_id = v_evento_chiapas
          AND ue.activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Administrador sin asignacion activa a Chiapas';
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
            FROM pg_temp.pagos p
            JOIN pg_temp.registros r ON r.id = p.registro_id
            LEFT JOIN pg_temp.promotoras m ON m.id = r.promotora_id
            LEFT JOIN pg_temp.asesores a ON a.id = r.asesor_id
            WHERE p.estado IN ('pendiente', 'revision')
              AND r.evento_id = v_evento_chiapas
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
            FROM pg_temp.registros r
            LEFT JOIN pg_temp.promotoras m ON m.id = r.promotora_id
            LEFT JOIN pg_temp.asesores a ON a.id = r.asesor_id
            LEFT JOIN LATERAL (
                SELECT iv.id, iv.estado, iv.emitida_at
                FROM pg_temp.invitaciones iv
                WHERE iv.registro_id = r.id
                ORDER BY
                    CASE WHEN iv.estado <> 'revocada' THEN 0 ELSE 1 END,
                    iv.emitida_at DESC NULLS LAST,
                    iv.id DESC
                LIMIT 1
            ) i ON TRUE
            WHERE r.evento_id = v_evento_chiapas
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
$function$
;

-- Copia del cuerpo final: crear_registro_publico_v3
CREATE OR REPLACE FUNCTION pg_temp.crear_registro_publico_v3(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_grupo_ruta text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
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
    IF p_foto_path IS NULL OR p_foto_path NOT LIKE p_evento_id::text || '/%'
    OR (p_comprobante_path IS NOT NULL AND p_comprobante_path NOT LIKE p_evento_id::text || '/%')
    THEN RAISE EXCEPTION 'Archivo de otro evento'; END IF;
    IF p_evento_id IS NULL OR p_evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid) THEN RAISE EXCEPTION 'Evento no autorizado'; END IF;
 -- Sólo las Edge Functions con service_role pueden guardar inscripciones.
 IF coalesce(auth.role(),'') <> 'service_role' THEN
   RAISE EXCEPTION 'Registro no autorizado';
 END IF;
 IF p_evento_id IS NULL OR NOT EXISTS (
  SELECT 1 FROM pg_temp.eventos WHERE id = p_evento_id
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
 FROM pg_temp.asesores WHERE id = p_asesor_id AND activo IS TRUE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Selecciona un asesor válido'; END IF;
 v_empleado := upper(btrim(v_nombre_asesor)) = 'EMPLEADO';
 IF v_empleado AND p_evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid THEN
   RAISE EXCEPTION 'Chiapas no admite empleados';
 END IF;
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
   pg_catalog.hashtextextended('ensayo-rollback-' || pg_catalog.pg_backend_pid()::text || '-' || p_evento_id::text, 0)
 );
 IF EXISTS (
    SELECT 1 FROM pg_temp.registros r
    JOIN pg_temp.promotoras p ON p.id = r.promotora_id
    WHERE r.evento_id = p_evento_id
      AND p.telefono_whatsapp = p_whatsapp
      AND coalesce(r.es_prueba,false) = v_es_prueba
      AND coalesce(r.estado,'pendiente') NOT IN ('cancelado','rechazado')
 ) THEN
    RETURN jsonb_build_object('ok',false,'codigo','DUPLICADO',
      'mensaje','Ya existe una inscripción con ese WhatsApp para este evento.');
 END IF;

 IF NOT v_es_prueba THEN
    SELECT cupo_maximo INTO v_maximo FROM pg_temp.configuracion_cupo_evento
    WHERE evento_id = p_evento_id;
    -- Bajo ninguna circunstancia pasar de 1500; mantener límites menores.
    v_limite := least(CASE WHEN p_evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid THEN 500 ELSE 1500 END, coalesce(v_maximo,1500), coalesce(p_max_registros,1500));
    SELECT count(*) INTO v_total FROM pg_temp.registros
    WHERE evento_id = p_evento_id AND NOT coalesce(es_prueba,false)
      AND coalesce(estado,'pendiente') NOT IN ('cancelado','rechazado');
    IF v_total >= v_limite THEN
      RETURN jsonb_build_object('ok',false,'codigo','SIN_CUPO',
        'mensaje','El evento ya alcanzó el cupo disponible.');
    END IF;
 END IF;

 INSERT INTO pg_temp.promotoras (
   nombres, apellidos, telefono_whatsapp, estado_residencia,
   tipo_participante, foto_path
 ) VALUES (
   btrim(p_nombres), btrim(p_apellidos), p_whatsapp,
   btrim(p_estado_residencia), p_tipo_participante, p_foto_path
 ) RETURNING id INTO v_promotora_id;

 v_folio := 'EA26-' || upper(replace(gen_random_uuid()::text,'-',''));
 INSERT INTO pg_temp.registros (
   evento_id, promotora_id, asesor_id, estado, exento_pago,
   folio, aviso_privacidad_aceptado_at, es_prueba, grupo_ruta
 ) VALUES (
   p_evento_id, v_promotora_id, p_asesor_id,
   'pendiente', FALSE, v_folio, now(), v_es_prueba, v_grupo
 ) RETURNING id INTO v_registro_id;

 -- No crear un pago ficticio de $300 para quien tendrá cortesía pendiente.
 IF NOT v_sin_pago THEN
   INSERT INTO pg_temp.pagos(registro_id,importe,comprobante_path,cuenta_destino,estado)
   VALUES(v_registro_id,300.00,p_comprobante_path,p_cuenta_destino,'pendiente');
 END IF;
 RETURN jsonb_build_object('ok',true,'folio',v_folio,
   'registro_id',v_registro_id,'estado','pendiente',
   'cortesia_pendiente',v_sin_pago,'es_prueba',v_es_prueba);
END;
$function$
;

-- Copia del cuerpo final: crear_perfil_evento_interno
CREATE OR REPLACE FUNCTION pg_temp.crear_perfil_evento_interno(p_admin_id uuid, p_evento_id uuid, p_usuario_id uuid, p_nombre text, p_nombre_usuario text, p_rol text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
   RAISE EXCEPTION 'Identidad incorrecta' USING ERRCODE='42501';
 END IF;
 IF p_evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid)
 OR NOT EXISTS (
   SELECT 1 FROM pg_temp.usuarios u JOIN pg_temp.usuarios_eventos ue ON ue.usuario_id=u.id
   WHERE u.id=p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
     AND ue.evento_id=p_evento_id AND ue.activo IS TRUE
 ) THEN RAISE EXCEPTION 'Administrador no autorizado' USING ERRCODE='42501'; END IF;
 IF p_usuario_id IS NULL OR p_evento_id IS NULL OR p_rol IS NULL
 OR p_rol NOT IN ('administrador','validador','recepcion','acceso')
 OR p_nombre IS NULL OR char_length(btrim(p_nombre)) NOT BETWEEN 2 AND 120
 OR p_nombre_usuario IS NULL OR p_nombre_usuario !~ '^[a-z][a-z0-9._-]{2,31}$'
 THEN RAISE EXCEPTION 'Perfil inválido'; END IF;
 INSERT INTO pg_temp.usuarios(id,nombre,nombre_usuario,rol,activo)
 VALUES(p_usuario_id,btrim(p_nombre),p_nombre_usuario,p_rol,true);
 INSERT INTO pg_temp.usuarios_eventos(usuario_id,evento_id,activo)
 VALUES(p_usuario_id,p_evento_id,true);
 INSERT INTO pg_temp.auditoria(usuario_id,accion,entidad,entidad_id,detalles)
 VALUES(p_admin_id,'crear_usuario','usuarios',p_usuario_id,jsonb_build_object('evento_id',p_evento_id,'rol',p_rol));
END;
$function$
;

-- Copia del cuerpo final: consultar_grupo_registro_admin
CREATE OR REPLACE FUNCTION pg_temp.consultar_grupo_registro_admin(p_registro_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_grupo text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM pg_temp.usuarios u WHERE u.id=auth.uid() AND u.activo IS TRUE AND u.rol='administrador'
 ) THEN RAISE EXCEPTION 'No autorizado' USING ERRCODE='42501'; END IF;
 SELECT r.grupo_ruta INTO v_grupo FROM pg_temp.registros r
 WHERE r.id=p_registro_id AND EXISTS (
   SELECT 1 FROM pg_temp.usuarios_eventos ue
   WHERE ue.usuario_id=auth.uid() AND ue.evento_id=r.evento_id AND ue.activo IS TRUE
 );
 IF NOT FOUND THEN RAISE EXCEPTION 'Inscripción no encontrada' USING ERRCODE='42501'; END IF;
 RETURN v_grupo;
END;
$function$
;

-- Copia del cuerpo final: evitar_acceso_duplicado
CREATE OR REPLACE FUNCTION pg_temp.evitar_acceso_duplicado()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_registro_id uuid;
BEGIN
  SELECT registro_id
  INTO v_registro_id
  FROM pg_temp.invitaciones
  WHERE id = NEW.invitacion_id;

  IF v_registro_id IS NULL THEN
    RAISE EXCEPTION 'Invitación inexistente';
  END IF;

  -- Serializa los intentos de acceso
  -- correspondientes a la misma inscripción.
  PERFORM 1
  FROM pg_temp.registros
  WHERE id = v_registro_id
  FOR UPDATE;

  IF EXISTS (
    SELECT 1
    FROM pg_temp.accesos a
    JOIN pg_temp.invitaciones i
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

-- Copia del cuerpo final: evitar_registro_duplicado
CREATE OR REPLACE FUNCTION pg_temp.evitar_registro_duplicado()
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
  FROM pg_temp.promotoras AS p
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
    FROM pg_temp.registros AS r
    JOIN pg_temp.promotoras AS p
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

-- Copia del cuerpo final: impedir_sobrecupo_evento
CREATE OR REPLACE FUNCTION pg_temp.impedir_sobrecupo_evento()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
    hashtextextended('ensayo-rollback-' || pg_catalog.pg_backend_pid()::text || '-' || NEW.evento_id::text, 0)
  );

  SELECT cupo_maximo INTO v_maximo
  FROM pg_temp.configuracion_cupo_evento
  WHERE evento_id = NEW.evento_id;

  IF NEW.evento_id IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid) THEN
    v_maximo := LEAST(coalesce(v_maximo,1500),CASE WHEN NEW.evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid THEN 500 ELSE 1500 END);
  END IF;
  IF v_maximo IS NULL THEN
    RETURN NEW; -- No imponemos límites a otros eventos sin configurar.
  END IF;

  SELECT count(*) INTO v_ocupados
  FROM pg_temp.registros r
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

-- Copia del cuerpo final: proteger_ultimo_administrador_activo
CREATE OR REPLACE FUNCTION pg_temp.proteger_ultimo_administrador_activo()
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
    FROM pg_temp.usuarios
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
CREATE TRIGGER trg_evitar_registro_duplicado BEFORE INSERT OR UPDATE OF evento_id, promotora_id ON pg_temp.registros FOR EACH ROW EXECUTE FUNCTION pg_temp.evitar_registro_duplicado();
CREATE TRIGGER trg_evitar_acceso_duplicado BEFORE INSERT ON pg_temp.accesos FOR EACH ROW EXECUTE FUNCTION pg_temp.evitar_acceso_duplicado();
CREATE TRIGGER registros_impedir_sobrecupo BEFORE INSERT OR UPDATE OF estado, evento_id, es_prueba ON pg_temp.registros FOR EACH ROW EXECUTE FUNCTION pg_temp.impedir_sobrecupo_evento();
CREATE TRIGGER trg_proteger_ultimo_administrador AFTER DELETE OR UPDATE OF rol, activo ON pg_temp.usuarios FOR EACH ROW EXECUTE FUNCTION pg_temp.proteger_ultimo_administrador_activo();
-- Casos y actores completamente ficticios. No crear usuarios Auth reales.
SELECT set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claim.role','service_role',true);
INSERT INTO pg_temp.usuarios(id,nombre,nombre_usuario,rol) VALUES
 ('00000000-0000-4000-8000-000000000001','PRUEBA ADMIN R','ensayo.admin.r','administrador'),
 ('00000000-0000-4000-8000-000000000002','PRUEBA ADMIN C','ensayo.admin.c','administrador'),
 ('00000000-0000-4000-8000-000000000003','PRUEBA VALID R','ensayo.valid.r','validador'),
 ('00000000-0000-4000-8000-000000000004','PRUEBA VALID C','ensayo.valid.c','validador');
INSERT INTO pg_temp.eventos(id,nombre,estado,fecha_inicio,sede,cuota_fija) VALUES
 ('43e67bda-d19d-4c0e-a639-e85f2d62f294','PRUEBA RADEVS','activo','2026-12-06','FICTICIA',300),
 ('3dc92160-79af-4bf7-b770-263038e88900','PRUEBA CHIAPAS','borrador','2026-12-19','FICTICIA',300);
INSERT INTO pg_temp.configuracion_cupo_evento(evento_id,cupo_maximo) VALUES
 ('43e67bda-d19d-4c0e-a639-e85f2d62f294',1500),('3dc92160-79af-4bf7-b770-263038e88900',500);
INSERT INTO pg_temp.usuarios_eventos(usuario_id,evento_id) VALUES
 ('00000000-0000-4000-8000-000000000001','43e67bda-d19d-4c0e-a639-e85f2d62f294'),
 ('00000000-0000-4000-8000-000000000002','3dc92160-79af-4bf7-b770-263038e88900'),
 ('00000000-0000-4000-8000-000000000003','43e67bda-d19d-4c0e-a639-e85f2d62f294'),
 ('00000000-0000-4000-8000-000000000004','3dc92160-79af-4bf7-b770-263038e88900');
INSERT INTO pg_temp.asesores(id,nombre) VALUES
 ('00000000-0000-4000-8000-000000000010','PRUEBA ASESOR'),('00000000-0000-4000-8000-000000000011','EMPLEADO');
CREATE FUNCTION pg_temp.registrar_ensayo(p_evento uuid,p_tel text,p_tipo text DEFAULT 'vendedora',p_empleado boolean DEFAULT false,p_foto text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql AS $register$
 SELECT pg_temp.crear_registro_publico_v3(p_evento,
 CASE WHEN p_empleado THEN '00000000-0000-4000-8000-000000000011'::uuid ELSE '00000000-0000-4000-8000-000000000010'::uuid END,
 'PRUEBA TEMPORAL','FICTICIA','Chiapas',p_tel,p_tipo,'RUTA FICTICIA',coalesce(p_foto,p_evento::text||'/foto.png'),
 CASE WHEN p_tipo='vendedora' THEN p_evento::text||'/pago.png' END,
 CASE WHEN p_tipo='vendedora' THEN 'CUENTA FICTICIA' END,NULL);
$register$;
DO $casos$
DECLARE
 r constant uuid:='43e67bda-d19d-4c0e-a639-e85f2d62f294';
 c constant uuid:='3dc92160-79af-4bf7-b770-263038e88900';
 ar constant uuid:='00000000-0000-4000-8000-000000000001';
 ac constant uuid:='00000000-0000-4000-8000-000000000002';
 vr constant uuid:='00000000-0000-4000-8000-000000000003';
 vc constant uuid:='00000000-0000-4000-8000-000000000004';
 rr uuid;rc uuid;cr uuid;cc uuid;pr uuid;pc uuid;j jsonb;jr jsonb;jc jsonb;token_anterior text;token_nuevo text;negado boolean;
BEGIN
 -- Confirmar que la identidad de auditoría no utiliza una secuencia pública.
 PERFORM pg_temp.verificar_ensayo('secuencia temporal',
  (SELECT seq.relnamespace=pg_my_temp_schema() FROM pg_class seq WHERE seq.oid=pg_get_serial_sequence('pg_temp.auditoria','id')::regclass));
 j:=pg_temp.registrar_ensayo(r,'5500000001');rr:=(j->>'registro_id')::uuid;
 PERFORM pg_temp.verificar_ensayo('alta RADEVS',j->>'ok'='true');
 j:=pg_temp.registrar_ensayo(c,'5500000001');rc:=(j->>'registro_id')::uuid;
 PERFORM pg_temp.verificar_ensayo('alta Chiapas mismo telefono',j->>'ok'='true' AND rc<>rr);
 PERFORM pg_temp.verificar_ensayo('duplicado por evento',pg_temp.registrar_ensayo(r,'5500000001')->>'codigo'='DUPLICADO');
 PERFORM pg_temp.verificar_ensayo('cuota 300',NOT EXISTS(SELECT 1 FROM pg_temp.pagos WHERE importe<>300));
 negado:=false;BEGIN PERFORM pg_temp.registrar_ensayo(c,'5500000002','promotora',true);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%empleados%';END;
 PERFORM pg_temp.verificar_ensayo('empleado bloqueado Chiapas',negado);
 negado:=false;BEGIN PERFORM pg_temp.registrar_ensayo(c,'5500000003','vendedora',false,r::text||'/ajena.png');EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%otro evento%';END;
 PERFORM pg_temp.verificar_ensayo('archivo ajeno bloqueado',negado);
 j:=pg_temp.registrar_ensayo(r,'5500000004','promotora');cr:=(j->>'registro_id')::uuid;
 j:=pg_temp.registrar_ensayo(c,'5500000005','promotora');cc:=(j->>'registro_id')::uuid;
 PERFORM pg_temp.verificar_ensayo('cortesias sin pagos ficticios',(SELECT count(*)=0 FROM pg_temp.pagos WHERE registro_id IN(cr,cc)));
 SELECT id INTO pr FROM pg_temp.pagos WHERE registro_id=rr;
 SELECT id INTO pc FROM pg_temp.pagos WHERE registro_id=rc;
 PERFORM set_config('request.jwt.claim.sub',vr::text,true);
 jr:=pg_temp.validar_pago_personal(pr,'aprobar',NULL);
 PERFORM pg_temp.verificar_ensayo('validador RADEVS emite QR',jr->>'ok'='true' AND length(jr#>>'{invitacion,token_qr}')=64);
 negado:=false;BEGIN PERFORM pg_temp.validar_pago_personal(pc,'aprobar',NULL);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%no existe%';END;
 PERFORM pg_temp.verificar_ensayo('pago Chiapas invisible en RADEVS',negado);
 PERFORM set_config('request.jwt.claim.sub',vc::text,true);
 jc:=pg_temp.validar_pago_personal_chiapas(pc,'aprobar',NULL);
 PERFORM pg_temp.verificar_ensayo('validador Chiapas emite QR',jc->>'ok'='true' AND length(jc#>>'{invitacion,token_qr}')=64);
 negado:=false;BEGIN PERFORM pg_temp.validar_pago_personal_chiapas(pr,'aprobar',NULL);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%no existe%';END;
 PERFORM pg_temp.verificar_ensayo('pago RADEVS invisible en Chiapas',negado);
 PERFORM set_config('request.jwt.claim.sub','',true);
 j:=pg_temp.recuperar_invitacion_admin_chiapas(rc,ac,false);
 PERFORM pg_temp.verificar_ensayo('recuperar conserva QR',j#>>'{invitacion,token_qr}'=jc#>>'{invitacion,token_qr}');
 negado:=false;BEGIN PERFORM pg_temp.recuperar_invitacion_admin_chiapas(rc,ar,false);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%autorizado%';END;
 PERFORM pg_temp.verificar_ensayo('admin sin asignacion Chiapas bloqueado',negado);
 PERFORM set_config('request.jwt.claim.sub',ac::text,true);
 negado:=false;BEGIN PERFORM pg_temp.consultar_grupo_registro_admin(rr);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%no encontrada%';END;
 PERFORM pg_temp.verificar_ensayo('grupo RADEVS invisible en Chiapas',negado);
 PERFORM pg_temp.verificar_ensayo('grupo propio visible',pg_temp.consultar_grupo_registro_admin(rc)='RUTA FICTICIA');
 PERFORM set_config('request.jwt.claim.sub','',true);
 j:=pg_temp.autorizar_cortesia_admin(cr,ar);
 PERFORM pg_temp.verificar_ensayo('cortesia RADEVS con QR',j->>'ok'='true' AND length(j#>>'{invitacion,token_qr}')=64);
 j:=pg_temp.autorizar_cortesia_admin_chiapas(cc,ac);
 PERFORM pg_temp.verificar_ensayo('cortesia Chiapas con QR',j->>'ok'='true' AND length(j#>>'{invitacion,token_qr}')=64);
 negado:=false;BEGIN PERFORM pg_temp.autorizar_cortesia_admin_chiapas(rc,ac);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%pago validado%';END;
 PERFORM pg_temp.verificar_ensayo('pago validado no convertido a cortesia',negado);
 j:=pg_temp.bandejas_admin_paginadas('invitaciones',1,'',ar);
 PERFORM pg_temp.verificar_ensayo('bandeja RADEVS aislada',(j->>'total')::int=2 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'registros') e WHERE (e->>'registro_id')::uuid IN(rc,cc)));
 j:=pg_temp.bandejas_admin_chiapas_paginadas('invitaciones',1,'',ac);
 PERFORM pg_temp.verificar_ensayo('bandeja Chiapas aislada',(j->>'total')::int=2 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'registros') e WHERE (e->>'registro_id')::uuid IN(rr,cr)));
 token_anterior:=jc#>>'{invitacion,token_qr}';
 j:=pg_temp.recuperar_invitacion_admin_chiapas(rc,ac,true);token_nuevo:=j#>>'{invitacion,token_qr}';
 PERFORM pg_temp.verificar_ensayo('reemision cambia QR',token_nuevo<>token_anterior);
 PERFORM set_config('request.jwt.claim.sub',ar::text,true);
 j:=pg_temp.registrar_entrada_qr_evento(token_nuevo,r);
 PERFORM pg_temp.verificar_ensayo('QR Chiapas rechazado RADEVS',j->>'ok'='false');
 PERFORM set_config('request.jwt.claim.sub',ac::text,true);
 j:=pg_temp.registrar_entrada_qr_evento(token_anterior,c);
 PERFORM pg_temp.verificar_ensayo('QR revocado rechazado',j->>'estado'='no_autorizado');
 j:=pg_temp.registrar_entrada_qr_evento(token_nuevo,c);
 PERFORM pg_temp.verificar_ensayo('entrada Chiapas registrada',j->>'estado'='ingreso_registrado');
 j:=pg_temp.registrar_entrada_qr_evento(token_nuevo,c);
 PERFORM pg_temp.verificar_ensayo('entrada duplicada rechazada',j->>'estado'='ya_ingreso' AND (SELECT count(*)=1 FROM pg_temp.accesos));
 UPDATE pg_temp.usuarios_eventos SET activo=false WHERE usuario_id=ac AND evento_id=c;
 negado:=false;BEGIN PERFORM pg_temp.consultar_qr_acceso_evento(token_nuevo,c);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%asignacion%';END;
 PERFORM pg_temp.verificar_ensayo('asignacion inactiva rechazada',negado);
 PERFORM pg_temp.verificar_ensayo('estados inscripcion conservados',(SELECT estado='activo' FROM pg_temp.eventos WHERE id=r) AND (SELECT estado='borrador' FROM pg_temp.eventos WHERE id=c));
 PERFORM pg_temp.verificar_ensayo('cupos separados conservados',(SELECT cupo_maximo=1500 FROM pg_temp.configuracion_cupo_evento WHERE evento_id=r) AND (SELECT cupo_maximo=500 FROM pg_temp.configuracion_cupo_evento WHERE evento_id=c));
 PERFORM pg_temp.verificar_ensayo('hashes QR correctos',NOT EXISTS(SELECT 1 FROM pg_temp.invitaciones i JOIN pg_temp.secretos_ensayo s ON s.id=i.token_vault_id WHERE i.token_hash<>encode(sha256(convert_to(s.decrypted_secret,'UTF8')),'hex')));
 PERFORM pg_temp.verificar_ensayo('funciones public y ACL sin cambios',
  (SELECT huella FROM pg_temp.catalogo_antes_ensayo) IS NOT DISTINCT FROM
  (SELECT md5(string_agg(p.oid::text||pg_get_functiondef(p.oid)||coalesce(p.proacl::text,''),'|' ORDER BY p.oid))
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f'));
 IF (SELECT count(*) FROM pg_temp.resultados_ensayo)<>31 THEN RAISE EXCEPTION 'Numero inesperado de casos'; END IF;
END;
$casos$;
ROLLBACK;
SELECT 'APROBADO' resultado,31 casos,
 to_regclass('pg_temp.resultados_ensayo') IS NULL AS rollback_sin_tablas_de_ensayo,
 'Solo pg_temp y datos ficticios; Vault simulado; sin Auth/Storage ni escrituras en public' alcance;
