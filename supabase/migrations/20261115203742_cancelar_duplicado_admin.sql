BEGIN;
CREATE FUNCTION public.cancelar_registro_duplicado_admin(p_evento_id uuid, p_admin_id uuid, p_registro_id uuid, p_folio_conservar text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO '' AS $$
DECLARE
  objetivo public.registros%ROWTYPE;
  conservar public.registros%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.usuarios u JOIN public.usuarios_eventos ue ON ue.usuario_id=u.id
    WHERE u.id=p_admin_id AND u.activo AND u.rol='administrador' AND ue.activo AND ue.evento_id=p_evento_id
  ) THEN
    RETURN jsonb_build_object('ok',false,'error','Sin permiso en el evento.');
  END IF;

  SELECT * INTO conservar FROM public.registros WHERE evento_id=p_evento_id AND folio=upper(btrim(p_folio_conservar));
  IF NOT FOUND OR conservar.id=p_registro_id THEN
    RETURN jsonb_build_object('ok',false,'error','Indica otro folio del mismo evento.');
  END IF;

  -- El flujo de aprobación toma el bloqueo del pago antes del registro.
  PERFORM p.id FROM public.pagos p JOIN public.registros r ON r.id=p.registro_id
    WHERE r.id=p_registro_id AND r.evento_id=p_evento_id ORDER BY p.id FOR UPDATE OF p;
  PERFORM id FROM public.registros WHERE evento_id=p_evento_id AND id IN (p_registro_id,conservar.id)
    ORDER BY id FOR UPDATE;
  SELECT * INTO objetivo FROM public.registros WHERE evento_id=p_evento_id AND id=p_registro_id;
  SELECT * INTO conservar FROM public.registros WHERE evento_id=p_evento_id AND folio=upper(btrim(p_folio_conservar));
  IF objetivo.id IS NULL OR conservar.id IS NULL OR objetivo.id=conservar.id
     OR conservar.estado IN ('cancelado','rechazado') OR objetivo.estado IN ('cancelado','rechazado')
     OR objetivo.es_prueba IS DISTINCT FROM conservar.es_prueba OR NOT EXISTS (
       SELECT 1 FROM public.promotoras p JOIN public.promotoras c ON c.id=conservar.promotora_id
       WHERE p.id=objetivo.promotora_id AND (
         nullif(p.telefono_whatsapp,'')=nullif(c.telefono_whatsapp,'') OR
         (translate(lower(btrim(regexp_replace(normalize(p.nombres), '[[:space:]]+', ' ', 'g'))), 'áéíóúü', 'aeiouu')=translate(lower(btrim(regexp_replace(normalize(c.nombres), '[[:space:]]+', ' ', 'g'))), 'áéíóúü', 'aeiouu') AND translate(lower(btrim(regexp_replace(normalize(p.apellidos), '[[:space:]]+', ' ', 'g'))), 'áéíóúü', 'aeiouu')=translate(lower(btrim(regexp_replace(normalize(c.apellidos), '[[:space:]]+', ' ', 'g'))), 'áéíóúü', 'aeiouu'))
       )
     ) THEN
    RETURN jsonb_build_object('ok',false,'error','El folio a conservar debe estar activo y coincidir en nombre o WhatsApp.');
  END IF;

  PERFORM id FROM public.invitaciones WHERE registro_id=objetivo.id ORDER BY id FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.pagos WHERE registro_id=objetivo.id AND estado='validado') OR EXISTS (
    SELECT 1 FROM public.accesos a JOIN public.invitaciones i ON i.id=a.invitacion_id WHERE i.registro_id=objetivo.id
  ) THEN
    RETURN jsonb_build_object('ok',false,'error','Esta ficha tiene pago aprobado o acceso registrado. Revisa cuál debes conservar.');
  END IF;

  UPDATE public.pagos SET estado='rechazado',validado_por=p_admin_id,validado_at=now()
    WHERE registro_id=objetivo.id AND estado IN ('pendiente','revision');
  UPDATE public.invitaciones SET estado='revocada',revocada_at=now()
    WHERE registro_id=objetivo.id AND estado IN ('emitida','activa');
  UPDATE public.registros SET estado='cancelado' WHERE id=objetivo.id;
  INSERT INTO public.auditoria(usuario_id,accion,entidad,entidad_id,detalles)
    VALUES(p_admin_id,'cancelar_duplicado','registros',objetivo.id,
      jsonb_build_object('estado_anterior',objetivo.estado,'registro_conservado',conservar.id,'folio_conservado',conservar.folio));
  RETURN jsonb_build_object('ok',true);
END;
$$;
REVOKE ALL ON FUNCTION public.cancelar_registro_duplicado_admin(uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_registro_duplicado_admin(uuid,uuid,uuid,text) TO service_role;
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

    IF v_pago.estado IS DISTINCT FROM 'pendiente'
       AND NOT (p_accion='rechazar' AND v_pago.estado IS NOT DISTINCT FROM 'revision') THEN
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

CREATE OR REPLACE FUNCTION public.validar_pago_admin_chiapas(p_pago_id uuid, p_accion text, p_motivo text, p_admin_id uuid)
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

    IF v_pago.estado IS DISTINCT FROM 'pendiente'
       AND NOT (p_accion='rechazar' AND v_pago.estado IS NOT DISTINCT FROM 'revision') THEN
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
COMMIT;
