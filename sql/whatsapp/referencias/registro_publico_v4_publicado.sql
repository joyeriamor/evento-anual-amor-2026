-- REFERENCIA AUDITADA. Ya existe en producción. NO incluir en la nueva migración.
CREATE OR REPLACE FUNCTION public.crear_registro_publico_v4(p_evento_id uuid, p_asesor_id uuid, p_nombres text, p_apellidos text, p_estado_residencia text, p_whatsapp text, p_tipo_participante text, p_grupo_ruta text, p_foto_path text, p_comprobante_path text, p_cuenta_destino text, p_max_registros integer DEFAULT NULL::integer, p_acepta_whatsapp boolean DEFAULT false)
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
 -- Guarda consentimiento explícito en la misma transacción del registro.
 IF COALESCE(p_acepta_whatsapp,FALSE) AND NOT v_es_prueba THEN
   INSERT INTO public.whatsapp_consentimientos_invitacion
     (registro_id,aceptado_at,origen,aviso_version,evidencia_referencia)
   VALUES (v_registro_id,now(),'formulario_registro',
     'whatsapp_invitacion_v1','checkbox_formulario_2026_v1');
 END IF;
 RETURN jsonb_build_object('ok',true,'folio',v_folio,
   'registro_id',v_registro_id,'estado','pendiente',
   'cortesia_pendiente',v_sin_pago,'es_prueba',v_es_prueba);
END;
$function$
