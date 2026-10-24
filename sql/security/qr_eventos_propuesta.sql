-- LOCAL ONLY. Based on the checked-in legacy implementation. Not executed.
BEGIN;

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

COMMIT;