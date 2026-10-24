-- LOCAL PACKAGE ONLY. Apply exclusively after explicit production approval.
-- No event states, registrations, payments or capacity configuration are changed.
BEGIN;
DO $catalog_preflight$
BEGIN
 IF to_regprocedure('public.autorizar_cortesia_admin(uuid,uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.autorizar_cortesia_admin(uuid,uuid)'))) IS DISTINCT FROM '4d53670065863b2915614991c74cc2f6' THEN RAISE EXCEPTION 'Definicion cambio: autorizar_cortesia_admin(uuid,uuid)'; END IF;
 IF to_regprocedure('public.bandejas_admin_paginadas(text,integer,text,uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.bandejas_admin_paginadas(text,integer,text,uuid)'))) IS DISTINCT FROM '5ceb57ad2bcdf48b25be363597e31466' THEN RAISE EXCEPTION 'Definicion cambio: bandejas_admin_paginadas(text,integer,text,uuid)'; END IF;
 IF to_regprocedure('public.comprobar_limite_login(text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.comprobar_limite_login(text)'))) IS DISTINCT FROM '5a5475803b087f64872cfe22c88abb04' THEN RAISE EXCEPTION 'Definicion cambio: comprobar_limite_login(text)'; END IF;
 IF to_regprocedure('public.comprobar_limite_registro(text,integer,integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.comprobar_limite_registro(text,integer,integer)'))) IS DISTINCT FROM 'f068535a65969b82cf1b2752eb236260' THEN RAISE EXCEPTION 'Definicion cambio: comprobar_limite_registro(text,integer,integer)'; END IF;
 IF to_regprocedure('public.consultar_grupo_registro_admin(uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.consultar_grupo_registro_admin(uuid)'))) IS DISTINCT FROM 'ba8405ff156013c5047e079a785bd1da' THEN RAISE EXCEPTION 'Definicion cambio: consultar_grupo_registro_admin(uuid)'; END IF;
 IF to_regprocedure('public.consultar_qr_acceso(text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.consultar_qr_acceso(text)'))) IS DISTINCT FROM '810c49ef2297ac3e82fd3c168bd8b136' THEN RAISE EXCEPTION 'Definicion cambio: consultar_qr_acceso(text)'; END IF;
 IF to_regprocedure('public.consultar_qr_acceso_evento(text,uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.consultar_qr_acceso_evento(text,uuid)'))) IS DISTINCT FROM 'f08bf7cdab85b1e3e6020a21d95db833' THEN RAISE EXCEPTION 'Definicion cambio: consultar_qr_acceso_evento(text,uuid)'; END IF;
 IF to_regprocedure('public.crear_inscripcion(uuid,text,text,text,text,uuid,text,text,text,uuid,text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_inscripcion(uuid,text,text,text,text,uuid,text,text,text,uuid,text)'))) IS DISTINCT FROM 'd9d29d0dd97dd4315d6bb89e1cae236d' THEN RAISE EXCEPTION 'Definicion cambio: crear_inscripcion(uuid,text,text,text,text,uuid,text,text,text,uuid,text)'; END IF;
 IF to_regprocedure('public.crear_registro_prueba_admin(uuid,uuid,text,text,text,text,text,text,text,text,integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_prueba_admin(uuid,uuid,text,text,text,text,text,text,text,text,integer)'))) IS DISTINCT FROM '2bf39bf3243dd41d716378e0c03e70a8' THEN RAISE EXCEPTION 'Definicion cambio: crear_registro_prueba_admin(uuid,uuid,text,text,text,text,text,text,text,text,integer)'; END IF;
 IF to_regprocedure('public.crear_registro_prueba_admin_v2(uuid,uuid,text,text,text,text,text,text,text,text,text,integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_prueba_admin_v2(uuid,uuid,text,text,text,text,text,text,text,text,text,integer)'))) IS DISTINCT FROM 'cca17c5b9588046217be3807f87fba66' THEN RAISE EXCEPTION 'Definicion cambio: crear_registro_prueba_admin_v2(uuid,uuid,text,text,text,text,text,text,text,text,text,integer)'; END IF;
 IF to_regprocedure('public.crear_registro_publico_v2(uuid,uuid,text,text,text,text,text,text,text,text,integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_publico_v2(uuid,uuid,text,text,text,text,text,text,text,text,integer)'))) IS DISTINCT FROM 'f9ae24bcb095e58a2d4ed7da8bf9d8a1' THEN RAISE EXCEPTION 'Definicion cambio: crear_registro_publico_v2(uuid,uuid,text,text,text,text,text,text,text,text,integer)'; END IF;
 IF to_regprocedure('public.crear_registro_publico_v3(uuid,uuid,text,text,text,text,text,text,text,text,text,integer)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.crear_registro_publico_v3(uuid,uuid,text,text,text,text,text,text,text,text,text,integer)'))) IS DISTINCT FROM 'dd57bf93778f2bd9ed4ed53d06c4a5c7' THEN RAISE EXCEPTION 'Definicion cambio: crear_registro_publico_v3(uuid,uuid,text,text,text,text,text,text,text,text,text,integer)'; END IF;
 IF to_regprocedure('public.emitir_invitacion_admin_interna(uuid,uuid,boolean)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.emitir_invitacion_admin_interna(uuid,uuid,boolean)'))) IS DISTINCT FROM '1447b79ee3ac3bf82835f1f2e0490bef' THEN RAISE EXCEPTION 'Definicion cambio: emitir_invitacion_admin_interna(uuid,uuid,boolean)'; END IF;
 IF to_regprocedure('public.evitar_acceso_duplicado()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.evitar_acceso_duplicado()'))) IS DISTINCT FROM 'cfc0b350cb58a5c61d1b0249c899db25' THEN RAISE EXCEPTION 'Definicion cambio: evitar_acceso_duplicado()'; END IF;
 IF to_regprocedure('public.evitar_registro_duplicado()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.evitar_registro_duplicado()'))) IS DISTINCT FROM 'ac117e4f20512564842dec8c8d635d80' THEN RAISE EXCEPTION 'Definicion cambio: evitar_registro_duplicado()'; END IF;
 IF to_regprocedure('public.impedir_sobrecupo_evento()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.impedir_sobrecupo_evento()'))) IS DISTINCT FROM 'a38aedde23f7ed6d098d7763d7273bf0' THEN RAISE EXCEPTION 'Definicion cambio: impedir_sobrecupo_evento()'; END IF;
 IF to_regprocedure('public.limpiar_limites_inicio_sesion()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.limpiar_limites_inicio_sesion()'))) IS DISTINCT FROM '3e2d712b4e25cacd906cfa4b16266b11' THEN RAISE EXCEPTION 'Definicion cambio: limpiar_limites_inicio_sesion()'; END IF;
 IF to_regprocedure('public.limpiar_limites_registro()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.limpiar_limites_registro()'))) IS DISTINCT FROM 'fc68df1238d9119c52333b7b17ea3353' THEN RAISE EXCEPTION 'Definicion cambio: limpiar_limites_registro()'; END IF;
 IF to_regprocedure('public.obtener_eventos_publicos()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.obtener_eventos_publicos()'))) IS DISTINCT FROM '0fd91d3ddd1dfc31db51b88e85a9012a' THEN RAISE EXCEPTION 'Definicion cambio: obtener_eventos_publicos()'; END IF;
 IF to_regprocedure('public.obtener_rol_usuario(uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.obtener_rol_usuario(uuid)'))) IS DISTINCT FROM 'ca9af07eb575c732f1e76cf5ce105d44' THEN RAISE EXCEPTION 'Definicion cambio: obtener_rol_usuario(uuid)'; END IF;
 IF to_regprocedure('public.operador_autorizado_evento(uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.operador_autorizado_evento(uuid)'))) IS DISTINCT FROM '9f54f852f6e70e4f688c5898e8f3a197' THEN RAISE EXCEPTION 'Definicion cambio: operador_autorizado_evento(uuid)'; END IF;
 IF to_regprocedure('public.proteger_ultimo_administrador_activo()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.proteger_ultimo_administrador_activo()'))) IS DISTINCT FROM '757742ed753b6fcd9223686e9572bd99' THEN RAISE EXCEPTION 'Definicion cambio: proteger_ultimo_administrador_activo()'; END IF;
 IF to_regprocedure('public.recuperar_invitacion_admin(uuid,uuid,boolean)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.recuperar_invitacion_admin(uuid,uuid,boolean)'))) IS DISTINCT FROM 'ca42ec72b3b0f2b482d6c3b8e4a760ca' THEN RAISE EXCEPTION 'Definicion cambio: recuperar_invitacion_admin(uuid,uuid,boolean)'; END IF;
 IF to_regprocedure('public.registrar_entrada_qr(text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.registrar_entrada_qr(text)'))) IS DISTINCT FROM '7ddff3b8899841bf5df7aa09cbe0c168' THEN RAISE EXCEPTION 'Definicion cambio: registrar_entrada_qr(text)'; END IF;
 IF to_regprocedure('public.registrar_entrada_qr_evento(text,uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.registrar_entrada_qr_evento(text,uuid)'))) IS DISTINCT FROM 'eb6d3905e76f6782b628533ed959b7ec' THEN RAISE EXCEPTION 'Definicion cambio: registrar_entrada_qr_evento(text,uuid)'; END IF;
 IF to_regprocedure('public.resumen_cupo_evento_interno(uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.resumen_cupo_evento_interno(uuid)'))) IS DISTINCT FROM 'dbc330f94af38448ebcb0e86c026afd4' THEN RAISE EXCEPTION 'Definicion cambio: resumen_cupo_evento_interno(uuid)'; END IF;
 IF to_regprocedure('public.rls_auto_enable()') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.rls_auto_enable()'))) IS DISTINCT FROM '846ec2fbff751d24b890656d63c3a9bf' THEN RAISE EXCEPTION 'Definicion cambio: rls_auto_enable()'; END IF;
 IF to_regprocedure('public.validar_pago_admin(uuid,text,text,uuid)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.validar_pago_admin(uuid,text,text,uuid)'))) IS DISTINCT FROM '1d9dda43554b32a8f75ecec77e17fcfe' THEN RAISE EXCEPTION 'Definicion cambio: validar_pago_admin(uuid,text,text,uuid)'; END IF;
 IF to_regprocedure('public.validar_pago_personal(uuid,text,text)') IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.validar_pago_personal(uuid,text,text)'))) IS DISTINCT FROM 'd6f4bab8e43fa8a99dca3d2e1508d14e' THEN RAISE EXCEPTION 'Definicion cambio: validar_pago_personal(uuid,text,text)'; END IF;
 IF to_regprocedure('public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text)') IS NOT NULL THEN RAISE EXCEPTION 'Funcion nueva ya existe: crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text)'; END IF;
 IF to_regprocedure('public.bandejas_admin_chiapas_paginadas(text,integer,text,uuid)') IS NOT NULL THEN RAISE EXCEPTION 'Funcion nueva ya existe: bandejas_admin_chiapas_paginadas(text,integer,text,uuid)'; END IF;
 IF to_regprocedure('public.recuperar_invitacion_admin_chiapas(uuid,uuid,boolean)') IS NOT NULL THEN RAISE EXCEPTION 'Funcion nueva ya existe: recuperar_invitacion_admin_chiapas(uuid,uuid,boolean)'; END IF;
 IF to_regprocedure('public.autorizar_cortesia_admin_chiapas(uuid,uuid)') IS NOT NULL THEN RAISE EXCEPTION 'Funcion nueva ya existe: autorizar_cortesia_admin_chiapas(uuid,uuid)'; END IF;
 IF to_regprocedure('public.validar_pago_admin_chiapas(uuid,text,text,uuid)') IS NOT NULL THEN RAISE EXCEPTION 'Funcion nueva ya existe: validar_pago_admin_chiapas(uuid,text,text,uuid)'; END IF;
 IF to_regprocedure('public.validar_pago_personal_chiapas(uuid,text,text)') IS NOT NULL THEN RAISE EXCEPTION 'Funcion nueva ya existe: validar_pago_personal_chiapas(uuid,text,text)'; END IF;
 IF to_regprocedure('public.emitir_invitacion_chiapas_interna(uuid,uuid,boolean)') IS NOT NULL THEN RAISE EXCEPTION 'Funcion nueva ya existe: emitir_invitacion_chiapas_interna(uuid,uuid,boolean)'; END IF;
END;
$catalog_preflight$;

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


-- Source: sql/chiapas/emitir_invitacion_chiapas_interna.sql
-- Generador independiente de Chiapas.
-- Preparado para revision y ensayos.
-- NO ejecutar en produccion hasta completar las pruebas.



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



-- Source: sql/chiapas/validar_pago_personal_chiapas_qr_integrado.sql



CREATE FUNCTION public.validar_pago_personal_chiapas(p_pago_id uuid, p_accion text, p_motivo text DEFAULT NULL::text)
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

    -- SEGURIDAD CHIAPAS:
    -- Exigir asignacion activa al evento.
    IF NOT EXISTS (
        SELECT 1
        FROM public.usuarios_eventos ue
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
    FROM public.pagos p JOIN public.registros r ON r.id=p.registro_id
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
    FROM public.registros
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
            public.emitir_invitacion_chiapas_interna(
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

-- La nueva funcion solo podra invocarse con sesion autenticada.
REVOKE ALL ON FUNCTION
    public.validar_pago_personal_chiapas(uuid,text,text)
    FROM PUBLIC;

REVOKE ALL ON FUNCTION
    public.validar_pago_personal_chiapas(uuid,text,text)
    FROM anon;

GRANT EXECUTE ON FUNCTION
    public.validar_pago_personal_chiapas(uuid,text,text)
    TO authenticated;



-- Source: sql/chiapas/funciones_administrativas_chiapas_propuesta.sql
-- Propuesta exclusiva de Chiapas.
-- No ejecutar hasta aprobar los ensayos y el despliegue.



CREATE FUNCTION public.validar_pago_admin_chiapas(p_pago_id uuid, p_accion text, p_motivo text, p_admin_id uuid)
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
        FROM public.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = TRUE
          AND EXISTS (
              SELECT 1
              FROM public.usuarios_eventos ue
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
    FROM public.pagos p JOIN public.registros r ON r.id=p.registro_id
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
    FROM public.registros
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
            public.emitir_invitacion_chiapas_interna(
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

REVOKE ALL ON FUNCTION public.validar_pago_admin_chiapas(uuid,text,text,uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.validar_pago_admin_chiapas(uuid,text,text,uuid)
TO service_role;

CREATE FUNCTION public.autorizar_cortesia_admin_chiapas(p_registro_id uuid, p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro public.registros%ROWTYPE;
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
        FROM public.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = TRUE
          AND EXISTS (
              SELECT 1
              FROM public.usuarios_eventos ue
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
    FROM public.registros
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
        public.emitir_invitacion_chiapas_interna(
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

REVOKE ALL ON FUNCTION public.autorizar_cortesia_admin_chiapas(uuid,uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.autorizar_cortesia_admin_chiapas(uuid,uuid)
TO service_role;

CREATE FUNCTION public.recuperar_invitacion_admin_chiapas(p_registro_id uuid, p_admin_id uuid, p_reemitir boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_registro public.registros%ROWTYPE;
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
        FROM public.usuarios
        WHERE id = p_admin_id
          AND rol = 'administrador'
          AND activo = true
          AND EXISTS (
              SELECT 1
              FROM public.usuarios_eventos ue
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
    FROM public.registros
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
        public.emitir_invitacion_chiapas_interna(
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

REVOKE ALL ON FUNCTION public.recuperar_invitacion_admin_chiapas(uuid,uuid,boolean)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.recuperar_invitacion_admin_chiapas(uuid,uuid,boolean)
TO service_role;



-- Source: sql/chiapas/bandejas_admin_chiapas_paginadas_propuesta.sql
-- EVENTO ANUAL AMOR 2026
-- Bandejas administrativas: busqueda, conteo y paginacion en PostgreSQL.
-- No cambia registros existentes ni habilita inscripciones publicas.
-- Instalar ANTES de desplegar la nueva Edge Function bandejas-admin.

CREATE OR REPLACE FUNCTION public.bandejas_admin_chiapas_paginadas(
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

    -- Un administrador global no obtiene acceso automatico a Chiapas.
    IF NOT EXISTS (
        SELECT 1
        FROM public.usuarios_eventos ue
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
            FROM public.pagos p
            JOIN public.registros r ON r.id = p.registro_id
            LEFT JOIN public.promotoras m ON m.id = r.promotora_id
            LEFT JOIN public.asesores a ON a.id = r.asesor_id
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
$function$;

-- Impedir llamadas directas desde el navegador.
REVOKE ALL ON FUNCTION public.bandejas_admin_chiapas_paginadas(text,integer,text,uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bandejas_admin_chiapas_paginadas(text,integer,text,uuid)
TO service_role;



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



-- Source: sql/security/qr_eventos_propuesta.sql
-- LOCAL ONLY. Based on the checked-in legacy implementation. Not executed.
CREATE OR REPLACE FUNCTION public.consultar_qr_acceso_evento(p_token text, p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_operador uuid := auth.uid();
    v_invitacion public.invitaciones%ROWTYPE;
    v_registro public.registros%ROWTYPE;
    v_ingreso timestamptz;
BEGIN

    IF p_evento_id IS NULL OR p_evento_id NOT IN (
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    ) OR NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador AND ue.evento_id = p_evento_id AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa al evento'; END IF;
    -- Solo administrador y acceso activos.
    IF v_operador IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.usuarios
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
    FROM public.invitaciones
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
    FROM public.registros
    WHERE id = v_invitacion.registro_id AND evento_id = p_evento_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'estado', 'no_confirmado'
        );
    END IF;

    SELECT MIN(a.ingresado_at)
    INTO v_ingreso
    FROM public.accesos a
    JOIN public.invitaciones i
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
                     FROM public.pagos p
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

CREATE OR REPLACE FUNCTION public.registrar_entrada_qr_evento(p_token text, p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_operador uuid := auth.uid();
  v_invitacion public.invitaciones%ROWTYPE;
  v_registro public.registros%ROWTYPE;
  v_ingreso timestamptz;
  v_acceso_id uuid;
BEGIN

    IF p_evento_id IS NULL OR p_evento_id NOT IN (
        '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,
        '3dc92160-79af-4bf7-b770-263038e88900'::uuid
    ) OR NOT EXISTS (
        SELECT 1 FROM public.usuarios_eventos ue
        WHERE ue.usuario_id = v_operador AND ue.evento_id = p_evento_id AND ue.activo IS TRUE
    ) THEN RAISE EXCEPTION 'Sin asignacion activa al evento'; END IF;
  IF v_operador IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.usuarios
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
  FROM public.invitaciones
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
  FROM public.registros
  WHERE id = v_invitacion.registro_id AND evento_id = p_evento_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'estado', 'qr_invalido');
  END IF;
  -- Refresh invitation AFTER acquiring the registration lock: a concurrent reissue
  -- must not let a revoked QR enter using a stale pre-lock snapshot.
  SELECT * INTO v_invitacion FROM public.invitaciones
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
       FROM public.pagos
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
  FROM public.accesos a
  JOIN public.invitaciones i
    ON i.id = a.invitacion_id
  WHERE i.registro_id = v_registro.id;

  IF v_ingreso IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'estado', 'ya_ingreso',
      'ingresado_at', v_ingreso
    );
  END IF;

  INSERT INTO public.accesos (
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

REVOKE ALL ON FUNCTION public.consultar_qr_acceso_evento(text,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.registrar_entrada_qr_evento(text,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consultar_qr_acceso_evento(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_qr_evento(text,uuid) TO authenticated;



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



-- Source: sql/security/perfiles_evento_propuesta.sql
-- Required by the server-side assignment guard. Current production ACL lacks these.
GRANT SELECT, INSERT, UPDATE ON public.usuarios_eventos TO service_role;

CREATE OR REPLACE FUNCTION public.consultar_grupo_registro_admin(p_registro_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_grupo text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.usuarios u WHERE u.id=auth.uid() AND u.activo IS TRUE AND u.rol='administrador'
 ) THEN RAISE EXCEPTION 'No autorizado' USING ERRCODE='42501'; END IF;
 SELECT r.grupo_ruta INTO v_grupo FROM public.registros r
 WHERE r.id=p_registro_id AND EXISTS (
   SELECT 1 FROM public.usuarios_eventos ue
   WHERE ue.usuario_id=auth.uid() AND ue.evento_id=r.evento_id AND ue.activo IS TRUE
 );
 IF NOT FOUND THEN RAISE EXCEPTION 'Inscripción no encontrada' USING ERRCODE='42501'; END IF;
 RETURN v_grupo;
END;
$function$;
REVOKE ALL ON FUNCTION public.consultar_grupo_registro_admin(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.consultar_grupo_registro_admin(uuid) TO authenticated;

-- Auth account is created by the Edge first. Profile + assignment are one DB transaction.
-- On failure, the Edge removes only the newly-created Auth account; no orphan profile.
CREATE FUNCTION public.crear_perfil_evento_interno(
 p_admin_id uuid,p_evento_id uuid,p_usuario_id uuid,p_nombre text,p_nombre_usuario text,p_rol text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NOT NULL AND auth.uid() IS DISTINCT FROM p_admin_id THEN
   RAISE EXCEPTION 'Identidad incorrecta' USING ERRCODE='42501';
 END IF;
 IF p_evento_id NOT IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid)
 OR NOT EXISTS (
   SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
   WHERE u.id=p_admin_id AND u.activo IS TRUE AND u.rol='administrador'
     AND ue.evento_id=p_evento_id AND ue.activo IS TRUE
 ) THEN RAISE EXCEPTION 'Administrador no autorizado' USING ERRCODE='42501'; END IF;
 IF p_usuario_id IS NULL OR p_evento_id IS NULL OR p_rol IS NULL
 OR p_rol NOT IN ('administrador','validador','recepcion','acceso')
 OR p_nombre IS NULL OR char_length(btrim(p_nombre)) NOT BETWEEN 2 AND 120
 OR p_nombre_usuario IS NULL OR p_nombre_usuario !~ '^[a-z][a-z0-9._-]{2,31}$'
 THEN RAISE EXCEPTION 'Perfil inválido'; END IF;
 INSERT INTO public.usuarios(id,nombre,nombre_usuario,rol,activo)
 VALUES(p_usuario_id,btrim(p_nombre),p_nombre_usuario,p_rol,true);
 INSERT INTO public.usuarios_eventos(usuario_id,evento_id,activo)
 VALUES(p_usuario_id,p_evento_id,true);
 INSERT INTO public.auditoria(usuario_id,accion,entidad,entidad_id,detalles)
 VALUES(p_admin_id,'crear_usuario','usuarios',p_usuario_id,jsonb_build_object('evento_id',p_evento_id,'rol',p_rol));
END;
$function$;
REVOKE ALL ON FUNCTION public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.crear_perfil_evento_interno(uuid,uuid,uuid,text,text,text) TO service_role;


-- Source: sql/security/registro_multievento_propuesta.sql
-- Prepared from the read-only catalog; no production data changes.

CREATE OR REPLACE FUNCTION public.crear_inscripcion(p_evento_id uuid, p_nombres text, p_apellidos text, p_telefono text, p_estado text, p_asesor_id uuid, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_solicitud_id uuid, p_privacidad_version text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_evento public.eventos%ROWTYPE;
  v_promotora_id uuid;
  v_registro_id uuid;
BEGIN
    IF p_foto_path IS NULL OR p_foto_path NOT LIKE p_evento_id::text || '/%'
    OR (p_comprobante_path IS NOT NULL AND p_comprobante_path NOT LIKE p_evento_id::text || '/%')
    THEN RAISE EXCEPTION 'Archivo de otro evento'; END IF;
    IF p_evento_id IS DISTINCT FROM '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN RAISE EXCEPTION 'Operacion exclusiva de RADEVS'; END IF;
  -- Esta función solo debe ejecutarse desde un
  -- contexto privilegiado del servidor.
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Operación no autorizada';
  END IF;

  SELECT *
  INTO v_evento
  FROM public.eventos
  WHERE id = p_evento_id
    AND estado = 'activo';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El evento no está disponible';
  END IF;

  IF length(trim(coalesce(p_nombres, ''))) < 2
     OR length(trim(coalesce(p_apellidos, ''))) < 2
     OR coalesce(p_telefono, '') !~ '^[0-9]{10}$'
     OR length(trim(coalesce(p_estado, ''))) < 2
     OR p_solicitud_id IS NULL
     OR length(trim(coalesce(p_foto_path, ''))) = 0
     OR length(trim(coalesce(p_comprobante_path, ''))) = 0
     OR length(trim(coalesce(p_cuenta_destino, ''))) = 0
     OR length(trim(coalesce(p_privacidad_version, ''))) = 0
  THEN
    RAISE EXCEPTION 'Datos de inscripción inválidos';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.asesores
    WHERE id = p_asesor_id
      AND activo = true
  ) THEN
    RAISE EXCEPTION 'Asesor no válido';
  END IF;

  -- Evitar procesar dos veces la misma solicitud.
  SELECT id
  INTO v_registro_id
  FROM public.registros
  WHERE solicitud_id = p_solicitud_id AND evento_id=p_evento_id;

  IF FOUND THEN
    RETURN v_registro_id;
  END IF;

  INSERT INTO public.promotoras (
    nombres,
    apellidos,
    telefono_whatsapp,
    estado_residencia,
    foto_path
  )
  VALUES (
    trim(p_nombres),
    trim(p_apellidos),
    p_telefono,
    trim(p_estado),
    p_foto_path
  )
  RETURNING id INTO v_promotora_id;

  INSERT INTO public.registros (
    evento_id,
    promotora_id,
    asesor_id,
    estado,
    solicitud_id,
    privacidad_aceptada_at,
    privacidad_version
  )
  VALUES (
    p_evento_id,
    v_promotora_id,
    p_asesor_id,
    'pendiente',
    p_solicitud_id,
    now(),
    p_privacidad_version
  )
  RETURNING id INTO v_registro_id;

  INSERT INTO public.pagos (
    registro_id,
    importe,
    comprobante_path,
    cuenta_destino,
    estado
  )
  VALUES (
    v_registro_id,
    v_evento.cuota_fija,
    p_comprobante_path,
    p_cuenta_destino,
    'pendiente'
  );

  RETURN v_registro_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.crear_registro_publico_v2(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_promotora_id uuid;
  v_registro_id uuid;
  v_folio text;
  v_total bigint;
  v_maximo integer;
  v_limite integer;
  v_es_prueba boolean := coalesce(current_setting('app.modo_prueba_admin', true), '') = 'si';
BEGIN
    IF p_foto_path IS NULL OR p_foto_path NOT LIKE p_evento_id::text || '/%'
    OR (p_comprobante_path IS NOT NULL AND p_comprobante_path NOT LIKE p_evento_id::text || '/%')
    THEN RAISE EXCEPTION 'Archivo de otro evento'; END IF;
    IF p_evento_id IS DISTINCT FROM '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN RAISE EXCEPTION 'Operacion exclusiva de RADEVS'; END IF;
  IF p_evento_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.eventos WHERE id = p_evento_id
  ) THEN
    RAISE EXCEPTION 'El evento no está disponible';
  END IF;
  IF p_nombres IS NULL OR length(btrim(p_nombres)) < 2 OR length(btrim(p_nombres)) > 100
     OR p_apellidos IS NULL OR length(btrim(p_apellidos)) < 2 OR length(btrim(p_apellidos)) > 100
     OR p_estado_residencia IS NULL OR length(btrim(p_estado_residencia)) < 2
     OR p_whatsapp IS NULL OR p_whatsapp !~ '^[0-9]{10}$'
     OR p_tipo_participante IS NULL OR p_tipo_participante NOT IN ('vendedora', 'promotora')
     OR p_foto_path IS NULL OR length(btrim(p_foto_path)) < 5
     OR p_comprobante_path IS NULL OR length(btrim(p_comprobante_path)) < 5
     OR p_cuenta_destino IS NULL OR length(btrim(p_cuenta_destino)) < 5
  THEN
    RAISE EXCEPTION 'Faltan datos obligatorios o contienen valores incorrectos';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.asesores WHERE id = p_asesor_id AND activo IS TRUE
  ) THEN
    RAISE EXCEPTION 'Selecciona un asesor válido';
  END IF;
  IF v_es_prueba AND coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'No autorizado para registrar una prueba';
  END IF;
  IF p_max_registros IS NOT NULL AND p_max_registros < 1 THEN
    RAISE EXCEPTION 'MAX_REGISTROS_EVENTO debe ser positivo';
  END IF;

  -- Protege DUPLICADOS y CUPO de dos altas simultáneas.
  PERFORM pg_advisory_xact_lock(
    hashtextextended('evento-anual-' || p_evento_id::text, 0)
  );

  -- Inscripciones de prueba y reales no compiten por WhatsApp.
  IF EXISTS (
    SELECT 1 FROM public.registros r
    JOIN public.promotoras p ON p.id = r.promotora_id
    WHERE r.evento_id = p_evento_id
      AND p.telefono_whatsapp = p_whatsapp
      AND coalesce(r.es_prueba, false) = v_es_prueba
      AND coalesce(r.estado, 'pendiente') NOT IN ('cancelado', 'rechazado')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'codigo', 'DUPLICADO',
      'mensaje', 'Ya existe una inscripción con ese WhatsApp para este evento.');
  END IF;

  IF NOT v_es_prueba THEN
    SELECT cupo_maximo INTO v_maximo
    FROM public.configuracion_cupo_evento WHERE evento_id = p_evento_id;
    -- El cupo configurado prevalece; un límite anterior más bajo es adicional.
    -- Otros eventos sin configuración conservan el comportamiento original.
    IF TRUE THEN
      v_limite := LEAST(1500,coalesce(v_maximo,1500),coalesce(p_max_registros,1500));
      SELECT count(*) INTO v_total
      FROM public.registros
      WHERE evento_id = p_evento_id
        AND NOT coalesce(es_prueba, false)
        AND coalesce(estado, 'pendiente') NOT IN ('cancelado', 'rechazado');
      IF v_total >= v_limite THEN
        RETURN jsonb_build_object('ok', false, 'codigo', 'SIN_CUPO',
          'mensaje', 'El evento ya alcanzó el cupo disponible.');
      END IF;
    END IF;
  END IF;

  INSERT INTO public.promotoras(
    nombres, apellidos, telefono_whatsapp, estado_residencia,
    tipo_participante, foto_path
  ) VALUES (
    btrim(p_nombres), btrim(p_apellidos), p_whatsapp,
    btrim(p_estado_residencia), p_tipo_participante, p_foto_path
  ) RETURNING id INTO v_promotora_id;

  v_folio := 'EA26-' || upper(replace(gen_random_uuid()::text, '-', ''));
  INSERT INTO public.registros(
    evento_id, promotora_id, asesor_id, estado, exento_pago, folio,
    aviso_privacidad_aceptado_at, es_prueba
  ) VALUES (
    p_evento_id, v_promotora_id, p_asesor_id,
    'pendiente', false, v_folio, now(), v_es_prueba
  ) RETURNING id INTO v_registro_id;

  INSERT INTO public.pagos(registro_id, importe, comprobante_path, cuenta_destino, estado)
  VALUES (v_registro_id, 300.00, p_comprobante_path, p_cuenta_destino, 'pendiente');

  RETURN jsonb_build_object(
    'ok', true, 'folio', v_folio, 'registro_id', v_registro_id,
    'estado', 'pendiente', 'es_prueba', v_es_prueba
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.crear_registro_publico_v3(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_grupo_ruta text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
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
  SELECT 1 FROM public.eventos WHERE id = p_evento_id
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
 FROM public.asesores WHERE id = p_asesor_id AND activo IS TRUE;
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
   pg_catalog.hashtextextended('evento-anual-' || p_evento_id::text, 0)
 );
 IF EXISTS (
    SELECT 1 FROM public.registros r
    JOIN public.promotoras p ON p.id = r.promotora_id
    WHERE r.evento_id = p_evento_id
      AND p.telefono_whatsapp = p_whatsapp
      AND coalesce(r.es_prueba,false) = v_es_prueba
      AND coalesce(r.estado,'pendiente') NOT IN ('cancelado','rechazado')
 ) THEN
    RETURN jsonb_build_object('ok',false,'codigo','DUPLICADO',
      'mensaje','Ya existe una inscripción con ese WhatsApp para este evento.');
 END IF;

 IF NOT v_es_prueba THEN
    SELECT cupo_maximo INTO v_maximo FROM public.configuracion_cupo_evento
    WHERE evento_id = p_evento_id;
    -- Bajo ninguna circunstancia pasar de 1500; mantener límites menores.
    v_limite := least(CASE WHEN p_evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid THEN 500 ELSE 1500 END, coalesce(v_maximo,1500), coalesce(p_max_registros,1500));
    SELECT count(*) INTO v_total FROM public.registros
    WHERE evento_id = p_evento_id AND NOT coalesce(es_prueba,false)
      AND coalesce(estado,'pendiente') NOT IN ('cancelado','rechazado');
    IF v_total >= v_limite THEN
      RETURN jsonb_build_object('ok',false,'codigo','SIN_CUPO',
        'mensaje','El evento ya alcanzó el cupo disponible.');
    END IF;
 END IF;

 INSERT INTO public.promotoras (
   nombres, apellidos, telefono_whatsapp, estado_residencia,
   tipo_participante, foto_path
 ) VALUES (
   btrim(p_nombres), btrim(p_apellidos), p_whatsapp,
   btrim(p_estado_residencia), p_tipo_participante, p_foto_path
 ) RETURNING id INTO v_promotora_id;

 v_folio := 'EA26-' || upper(replace(gen_random_uuid()::text,'-',''));
 INSERT INTO public.registros (
   evento_id, promotora_id, asesor_id, estado, exento_pago,
   folio, aviso_privacidad_aceptado_at, es_prueba, grupo_ruta
 ) VALUES (
   p_evento_id, v_promotora_id, p_asesor_id,
   'pendiente', FALSE, v_folio, now(), v_es_prueba, v_grupo
 ) RETURNING id INTO v_registro_id;

 -- No crear un pago ficticio de $300 para quien tendrá cortesía pendiente.
 IF NOT v_sin_pago THEN
   INSERT INTO public.pagos(registro_id,importe,comprobante_path,cuenta_destino,estado)
   VALUES(v_registro_id,300.00,p_comprobante_path,p_cuenta_destino,'pendiente');
 END IF;
 RETURN jsonb_build_object('ok',true,'folio',v_folio,
   'registro_id',v_registro_id,'estado','pendiente',
   'cortesia_pendiente',v_sin_pago,'es_prueba',v_es_prueba);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.crear_registro_prueba_admin(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_resultado jsonb;
  v_registro_id uuid;
BEGIN
    IF p_evento_id IS DISTINCT FROM '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN RAISE EXCEPTION 'Operacion exclusiva de RADEVS'; END IF;
  IF p_nombres IS NULL OR p_nombres !~* '^PRUEBA([ -]|$)' THEN
    RAISE EXCEPTION 'El nombre debe comenzar con PRUEBA';
  END IF;
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Solo el backend autorizado puede registrar pruebas';
  END IF;

  -- La marca se transmite por sesión SQL INTERNA, no por petición pública.
  -- set_config(..., true) la limita a esta transacción de la llamada RPC.
  PERFORM set_config('app.modo_prueba_admin', 'si', true);
  v_resultado := public.crear_registro_publico_v2(
    p_evento_id, p_asesor_id, p_nombres, p_apellidos,
    p_estado_residencia, p_whatsapp, p_tipo_participante,
    p_foto_path, p_comprobante_path, p_cuenta_destino, NULL
  );
  PERFORM set_config('app.modo_prueba_admin', '', true);

  IF coalesce((v_resultado ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_resultado;
  END IF;
  v_registro_id := (v_resultado ->> 'registro_id')::uuid;
  IF NOT EXISTS (
    SELECT 1 FROM public.registros
    WHERE id = v_registro_id AND evento_id = p_evento_id AND es_prueba IS TRUE
  ) THEN
    RAISE EXCEPTION 'La inscripción de prueba no quedó identificada correctamente';
  END IF;
  RETURN v_resultado || jsonb_build_object('es_prueba', true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.crear_registro_prueba_admin_v2(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_grupo_ruta text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_resultado jsonb;
 v_registro_id uuid;
BEGIN
    IF p_evento_id IS DISTINCT FROM '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid THEN RAISE EXCEPTION 'Operacion exclusiva de RADEVS'; END IF;
 IF coalesce(auth.role(),'') <> 'service_role' THEN
   RAISE EXCEPTION 'Solo el backend autorizado puede registrar pruebas';
 END IF;
 IF p_nombres IS NULL OR p_nombres !~* '^PRUEBA([ -]|$)' THEN
   RAISE EXCEPTION 'El nombre debe comenzar con PRUEBA';
 END IF;
 PERFORM set_config('app.modo_prueba_admin','si',true);
 v_resultado := public.crear_registro_publico_v3(
   p_evento_id, p_asesor_id, p_nombres, p_apellidos,
   p_estado_residencia, p_whatsapp, p_tipo_participante,
   p_grupo_ruta, p_foto_path, p_comprobante_path,
   p_cuenta_destino, NULL
 );
 PERFORM set_config('app.modo_prueba_admin','',true);
 IF coalesce((v_resultado->>'ok')::boolean,false) IS NOT TRUE THEN
   RETURN v_resultado;
 END IF;
 v_registro_id := (v_resultado->>'registro_id')::uuid;
 IF NOT EXISTS (
   SELECT 1 FROM public.registros WHERE id = v_registro_id
    AND evento_id = p_evento_id AND es_prueba IS TRUE
 ) THEN
   RAISE EXCEPTION 'El registro de prueba no quedó identificado';
 END IF;
 RETURN v_resultado || jsonb_build_object('es_prueba',true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.impedir_sobrecupo_evento()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
    hashtextextended('evento-anual-' || NEW.evento_id::text, 0)
  );

  SELECT cupo_maximo INTO v_maximo
  FROM public.configuracion_cupo_evento
  WHERE evento_id = NEW.evento_id;

  IF NEW.evento_id IN ('43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid,'3dc92160-79af-4bf7-b770-263038e88900'::uuid) THEN
    v_maximo := LEAST(coalesce(v_maximo,1500),CASE WHEN NEW.evento_id='3dc92160-79af-4bf7-b770-263038e88900'::uuid THEN 500 ELSE 1500 END);
  END IF;
  IF v_maximo IS NULL THEN
    RETURN NEW; -- No imponemos límites a otros eventos sin configurar.
  END IF;

  SELECT count(*) INTO v_ocupados
  FROM public.registros r
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



-- Source: sql/security/rls_storage_propuesta.sql
-- LOCAL ONLY. Review existing policies and schema dump; rehearse in disposable DB.
-- Restrictive policies intersect existing permissive policies; they grant no new access.
ALTER TABLE public.registros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accesos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_eventos ENABLE ROW LEVEL SECURITY;
-- Anonymous users access only the dedicated public registration endpoints, never tables.
DO $policies$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('CREATE POLICY evento_privado_anon ON public.%I AS RESTRICTIVE FOR SELECT TO anon USING (false)',t);
  END LOOP;
END;
$policies$;
CREATE POLICY evento_perfil_propio ON public.usuarios AS RESTRICTIVE
FOR SELECT TO authenticated USING (id=(SELECT auth.uid()) AND activo IS TRUE);
CREATE POLICY evento_promotoras_lectura ON public.promotoras AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r WHERE r.promotora_id=promotoras.id)
);
-- All writes use the authorized Edge endpoints or checked SECURITY DEFINER RPCs.
DO $writes$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['usuarios','usuarios_eventos','promotoras','registros','pagos','invitaciones','accesos','auditoria'] LOOP
    EXECUTE format('CREATE POLICY evento_solo_backend_insert ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated,anon WITH CHECK(false)',t);
    EXECUTE format('CREATE POLICY evento_solo_backend_update ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated,anon USING(false) WITH CHECK(false)',t);
    EXECUTE format('CREATE POLICY evento_solo_backend_delete ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated,anon USING(false)',t);
  END LOOP;
END;
$writes$;
CREATE POLICY evento_auditoria_propia ON public.auditoria AS RESTRICTIVE
FOR SELECT TO authenticated USING (usuario_id=(SELECT auth.uid()));
CREATE POLICY evento_asignacion_propia ON public.usuarios_eventos AS RESTRICTIVE
FOR SELECT TO authenticated USING (usuario_id = (SELECT auth.uid()) AND activo IS TRUE);
CREATE POLICY evento_registros_lectura ON public.registros AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
    WHERE u.id=(SELECT auth.uid()) AND u.activo IS TRUE AND ue.activo IS TRUE
      AND ue.evento_id=registros.evento_id
      AND u.rol IN ('administrador','validador','recepcion','acceso'))
);
CREATE POLICY evento_pagos_lectura ON public.pagos AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
    JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE r.id=pagos.registro_id AND u.id=(SELECT auth.uid())
      AND u.activo IS TRUE AND ue.activo IS TRUE AND u.rol IN ('administrador','validador'))
);
CREATE POLICY evento_invitaciones_lectura ON public.invitaciones AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.registros r WHERE r.id=invitaciones.registro_id)
);
CREATE POLICY evento_accesos_lectura ON public.accesos AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.invitaciones i WHERE i.id=accesos.invitacion_id)
);
CREATE POLICY evento_comprobantes_lectura ON storage.objects AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  bucket_id <> 'comprobantes-pago' OR EXISTS (
    SELECT 1 FROM public.pagos p JOIN public.registros r ON r.id=p.registro_id
      JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
      JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE p.comprobante_path=storage.objects.name AND u.id=(SELECT auth.uid())
      AND ue.activo IS TRUE AND u.activo IS TRUE AND u.rol IN ('administrador','validador')
  )
);
CREATE POLICY evento_fotos_lectura ON storage.objects AS RESTRICTIVE
FOR SELECT TO authenticated USING (
  bucket_id <> 'fotos-promotoras' OR EXISTS (
    SELECT 1 FROM public.promotoras p JOIN public.registros r ON r.promotora_id=p.id
      JOIN public.usuarios_eventos ue ON ue.evento_id=r.evento_id
      JOIN public.usuarios u ON u.id=ue.usuario_id
    WHERE p.foto_path=storage.objects.name AND u.id=(SELECT auth.uid())
      AND ue.activo IS TRUE AND u.activo IS TRUE
      AND u.rol IN ('administrador','validador','recepcion','acceso')
  )
);
CREATE POLICY evento_archivos_anon ON storage.objects AS RESTRICTIVE
FOR SELECT TO anon USING (bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_insert ON storage.objects AS RESTRICTIVE
FOR INSERT TO authenticated,anon WITH CHECK(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_update ON storage.objects AS RESTRICTIVE
FOR UPDATE TO authenticated,anon
USING(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'))
WITH CHECK(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
CREATE POLICY evento_archivos_delete ON storage.objects AS RESTRICTIVE
FOR DELETE TO authenticated,anon USING(bucket_id NOT IN ('comprobantes-pago','fotos-promotoras'));
-- Public bucket URLs bypass RLS. Private status is a prerequisite, not a substitute.
UPDATE storage.buckets SET public=false WHERE id IN ('comprobantes-pago','fotos-promotoras');

COMMIT;
