-- ENSAYO TEMPORAL. NO ES UNA MIGRACION.
-- La funcion se creara dentro de una transaccion y se revertira.

BEGIN;

DO $precheck$
BEGIN
    IF to_regprocedure(
        'public.bandejas_admin_chiapas_paginadas(text,integer,text,uuid)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION
            'La funcion Chiapas ya existe. No reemplazarla durante el ensayo.';
    END IF;
END;
$precheck$;
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


-- Verificaciones dentro de la misma transaccion.
DO $test$
DECLARE
    v_firma CONSTANT text :=
        'public.bandejas_admin_chiapas_paginadas(text,integer,text,uuid)';
    v_admin uuid;
    v_tipo text;
BEGIN
    IF to_regprocedure(v_firma) IS NULL THEN
        RAISE EXCEPTION 'No se creo la funcion de ensayo';
    END IF;

    IF has_function_privilege('anon', v_firma, 'EXECUTE') THEN
        RAISE EXCEPTION 'ALERTA: anon puede ejecutar la funcion';
    END IF;

    IF has_function_privilege('authenticated', v_firma, 'EXECUTE') THEN
        RAISE EXCEPTION 'ALERTA: authenticated puede ejecutar la funcion';
    END IF;

    IF NOT has_function_privilege('service_role', v_firma, 'EXECUTE') THEN
        RAISE EXCEPTION 'ALERTA: service_role no puede ejecutar la funcion';
    END IF;

    RAISE NOTICE 'APROBADO: permisos SQL';

    FOR v_tipo IN
        SELECT unnest(ARRAY['pagos', 'invitaciones'])
    LOOP
        BEGIN
            PERFORM public.bandejas_admin_chiapas_paginadas(
                v_tipo,
                1,
                '',
                '00000000-0000-0000-0000-000000000000'::uuid
            );

            RAISE EXCEPTION
                'FALLO: se autorizo un administrador inexistente para %',
                v_tipo;

        EXCEPTION WHEN OTHERS THEN
            IF SQLERRM = 'Administrador no autorizado' THEN
                RAISE NOTICE
                    'APROBADO: administrador inexistente rechazado en %',
                    v_tipo;
            ELSE
                RAISE;
            END IF;
        END;
    END LOOP;

    SELECT u.id
    INTO v_admin
    FROM public.usuarios u
    WHERE u.rol = 'administrador'
      AND u.activo = TRUE
      AND NOT EXISTS (
          SELECT 1
          FROM public.usuarios_eventos ue
          WHERE ue.usuario_id = u.id
            AND ue.evento_id =
                '3dc92160-79af-4bf7-b770-263038e88900'::uuid
            AND ue.activo = TRUE
      )
    LIMIT 1;

    IF v_admin IS NULL THEN
        RAISE NOTICE
            'SIN PROBAR: no hay administrador activo sin asignacion';
    ELSE
        FOR v_tipo IN
            SELECT unnest(ARRAY['pagos', 'invitaciones'])
        LOOP
            BEGIN
                PERFORM public.bandejas_admin_chiapas_paginadas(
                    v_tipo, 1, '', v_admin
                );

                RAISE EXCEPTION
                    'FALLO: administrador no asignado obtuvo acceso a %',
                    v_tipo;

            EXCEPTION WHEN OTHERS THEN
                IF SQLERRM =
                    'Administrador sin asignacion activa a Chiapas'
                THEN
                    RAISE NOTICE
                        'APROBADO: administrador no asignado rechazado en %',
                        v_tipo;
                ELSE
                    RAISE;
                END IF;
            END;
        END LOOP;
    END IF;

    RAISE NOTICE 'ENSAYO DE RECHAZOS COMPLETADO';
END;
$test$;

-- IMPORTANTE: no conservar la funcion en la base de datos.
ROLLBACK;