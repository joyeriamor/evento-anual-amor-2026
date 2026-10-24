-- ENSAYO POSITIVO: DATOS TOTALMENTE FICTICIOS.
-- El esquema y sus registros desaparecen con ROLLBACK.
BEGIN;

CREATE SCHEMA chiapas_ensayo_15192;

CREATE TABLE chiapas_ensayo_15192.usuarios (
    id uuid, rol text, activo boolean
);

CREATE TABLE chiapas_ensayo_15192.usuarios_eventos (
    usuario_id uuid, evento_id uuid, activo boolean
);

CREATE TABLE chiapas_ensayo_15192.promotoras (
    id uuid, nombres text, apellidos text,
    telefono_whatsapp text
);

CREATE TABLE chiapas_ensayo_15192.asesores (
    id uuid, nombre text
);

CREATE TABLE chiapas_ensayo_15192.registros (
    id uuid, folio text, estado text,
    exento_pago boolean, created_at timestamptz,
    promotora_id uuid, asesor_id uuid, evento_id uuid
);

CREATE TABLE chiapas_ensayo_15192.pagos (
    id uuid, registro_id uuid, estado text,
    importe numeric, referencia text,
    created_at timestamptz
);

CREATE TABLE chiapas_ensayo_15192.invitaciones (
    id uuid, registro_id uuid, estado text,
    emitida_at timestamptz
);

INSERT INTO chiapas_ensayo_15192.usuarios VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','administrador',true),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','administrador',true),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3','administrador',false),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','validador',true);

INSERT INTO chiapas_ensayo_15192.usuarios_eventos VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
 '3dc92160-79af-4bf7-b770-263038e88900',true),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
 '43e67bda-d19d-4c0e-a639-e85f2d62f294',true),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
 '3dc92160-79af-4bf7-b770-263038e88900',true),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
 '3dc92160-79af-4bf7-b770-263038e88900',true);

INSERT INTO chiapas_ensayo_15192.promotoras VALUES
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
 'CHIAPAS','FICTICIO','0000000001'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
 'RADEVS','FICTICIO','0000000002');

INSERT INTO chiapas_ensayo_15192.registros
(id,folio,estado,exento_pago,created_at,
 promotora_id,asesor_id,evento_id)
SELECT
 ('11111111-1111-4111-8111-' || lpad(n::text,12,'0'))::uuid,
 'CHI-' || n, 'pendiente', false,
 timestamptz '2026-10-24 10:00:00+00'
     + n * interval '1 minute',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'::uuid,
 NULL,
 '3dc92160-79af-4bf7-b770-263038e88900'::uuid
FROM generate_series(1,25) AS n;

INSERT INTO chiapas_ensayo_15192.registros
(id,folio,estado,exento_pago,created_at,
 promotora_id,asesor_id,evento_id)
SELECT
 ('22222222-2222-4222-8222-' || lpad(n::text,12,'0'))::uuid,
 'RAD-' || n, 'pendiente', false,
 timestamptz '2026-10-24 12:00:00+00'
     + n * interval '1 minute',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'::uuid,
 NULL,
 '43e67bda-d19d-4c0e-a639-e85f2d62f294'::uuid
FROM generate_series(1,3) AS n;

INSERT INTO chiapas_ensayo_15192.pagos
(id,registro_id,estado,importe,referencia,created_at)
SELECT
 ('33333333-3333-4333-8333-' || lpad(n::text,12,'0'))::uuid,
 ('11111111-1111-4111-8111-' || lpad(n::text,12,'0'))::uuid,
 'pendiente',300,'PAGO-CHI-' || n,
 timestamptz '2026-10-24 10:00:00+00'
     + n * interval '1 minute'
FROM generate_series(1,25) AS n;

INSERT INTO chiapas_ensayo_15192.pagos
(id,registro_id,estado,importe,referencia,created_at)
SELECT
 ('44444444-4444-4444-8444-' || lpad(n::text,12,'0'))::uuid,
 ('22222222-2222-4222-8222-' || lpad(n::text,12,'0'))::uuid,
 'pendiente',300,'PAGO-RAD-' || n,
 timestamptz '2026-10-24 12:00:00+00'
     + n * interval '1 minute'
FROM generate_series(1,3) AS n;

INSERT INTO chiapas_ensayo_15192.invitaciones
(id,registro_id,estado,emitida_at)
SELECT
 ('55555555-5555-4555-8555-' || lpad(n::text,12,'0'))::uuid,
 ('11111111-1111-4111-8111-' || lpad(n::text,12,'0'))::uuid,
 'emitida',
 timestamptz '2026-10-24 10:00:00+00'
     + n * interval '1 minute'
FROM generate_series(1,25) AS n;

INSERT INTO chiapas_ensayo_15192.invitaciones
(id,registro_id,estado,emitida_at)
SELECT
 ('66666666-6666-4666-8666-' || lpad(n::text,12,'0'))::uuid,
 ('22222222-2222-4222-8222-' || lpad(n::text,12,'0'))::uuid,
 'emitida',
 timestamptz '2026-10-24 12:00:00+00'
     + n * interval '1 minute'
FROM generate_series(1,3) AS n;

-- EVENTO ANUAL AMOR 2026
-- Bandejas administrativas: busqueda, conteo y paginacion en PostgreSQL.
-- No cambia registros existentes ni habilita inscripciones publicas.
-- Instalar ANTES de desplegar la nueva Edge Function bandejas-admin.


CREATE OR REPLACE FUNCTION chiapas_ensayo_15192.bandejas_admin_chiapas_paginadas(
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
        FROM chiapas_ensayo_15192.usuarios
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
        FROM chiapas_ensayo_15192.usuarios_eventos ue
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
            FROM chiapas_ensayo_15192.pagos p
            JOIN chiapas_ensayo_15192.registros r ON r.id = p.registro_id
            LEFT JOIN chiapas_ensayo_15192.promotoras m ON m.id = r.promotora_id
            LEFT JOIN chiapas_ensayo_15192.asesores a ON a.id = r.asesor_id
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
            FROM chiapas_ensayo_15192.registros r
            LEFT JOIN chiapas_ensayo_15192.promotoras m ON m.id = r.promotora_id
            LEFT JOIN chiapas_ensayo_15192.asesores a ON a.id = r.asesor_id
            LEFT JOIN LATERAL (
                SELECT iv.id, iv.estado, iv.emitida_at
                FROM chiapas_ensayo_15192.invitaciones iv
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
REVOKE ALL ON FUNCTION chiapas_ensayo_15192.bandejas_admin_chiapas_paginadas(text,integer,text,uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION chiapas_ensayo_15192.bandejas_admin_chiapas_paginadas(text,integer,text,uuid)
TO service_role;



-- Anular JWT para este ensayo SQL sin sesiones reales.
SELECT set_config('request.jwt.claim.sub','',true);

DO $pruebas$
DECLARE
    v_tipo text;
    v_pagina integer;
    v_res jsonb;
    v_esperadas integer;
    v_usuario uuid :=
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
    v_sin_acceso uuid :=
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
    v_inactivo uuid :=
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3';
    v_validador uuid :=
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
BEGIN
    IF auth.uid() IS NOT NULL THEN
        RAISE EXCEPTION 'El JWT ficticio no esta vacio';
    END IF;

    FOREACH v_tipo IN ARRAY ARRAY['pagos','invitaciones']
    LOOP
        -- Administradores ajenos a Chiapas deben fallar.
        BEGIN
            PERFORM chiapas_ensayo_15192.bandejas_admin_chiapas_paginadas(
                v_tipo,1,'',v_sin_acceso
            );
            RAISE EXCEPTION 'FALLO: usuario RADEVS autorizado';
        EXCEPTION WHEN OTHERS THEN
            IF SQLERRM <>
                'Administrador sin asignacion activa a Chiapas'
            THEN
                RAISE;
            END IF;
        END;

        -- Cuenta administrativa inactiva.
        BEGIN
            PERFORM chiapas_ensayo_15192.bandejas_admin_chiapas_paginadas(
                v_tipo,1,'',v_inactivo
            );
            RAISE EXCEPTION 'FALLO: usuario inactivo autorizado';
        EXCEPTION WHEN OTHERS THEN
            IF SQLERRM <> 'Administrador no autorizado' THEN
                RAISE;
            END IF;
        END;

        -- Rol sin privilegios administrativos.
        BEGIN
            PERFORM chiapas_ensayo_15192.bandejas_admin_chiapas_paginadas(
                v_tipo,1,'',v_validador
            );
            RAISE EXCEPTION 'FALLO: validador autorizado';
        EXCEPTION WHEN OTHERS THEN
            IF SQLERRM <> 'Administrador no autorizado' THEN
                RAISE;
            END IF;
        END;

        -- Chiapas tiene 25 registros, repartidos en 20 + 5.
        FOR v_pagina IN 1..2
        LOOP
            v_esperadas := CASE
                WHEN v_pagina = 1 THEN 20 ELSE 5 END;

            v_res :=
                chiapas_ensayo_15192.bandejas_admin_chiapas_paginadas(
                    v_tipo,v_pagina,'',v_usuario
                );

            IF (v_res->>'total')::integer <> 25 THEN
                RAISE EXCEPTION
                    'FALLO: total de % = %',
                    v_tipo,v_res->>'total';
            END IF;

            IF jsonb_array_length(v_res->'registros')
                <> v_esperadas
            THEN
                RAISE EXCEPTION
                    'FALLO: paginacion de %, pagina %',
                    v_tipo,v_pagina;
            END IF;

            IF EXISTS (
                SELECT 1
                FROM jsonb_array_elements(v_res->'registros') f
                WHERE f->>'folio' NOT LIKE 'CHI-%'
            ) THEN
                RAISE EXCEPTION
                    'FALLO: filtracion de RADEVS en %',
                    v_tipo;
            END IF;
        END LOOP;

        -- Buscar RADEV'S desde Chiapas nunca debe devolver datos.
        v_res :=
            chiapas_ensayo_15192.bandejas_admin_chiapas_paginadas(
                v_tipo,1,'RADEVS',v_usuario
            );

        IF (v_res->>'total')::integer <> 0 OR
           jsonb_array_length(v_res->'registros') <> 0
        THEN
            RAISE EXCEPTION
                'FALLO: busqueda cruzada en %',v_tipo;
        END IF;

        RAISE NOTICE
            'APROBADO: %, 25 registros, paginas 20/5, sin cruces',
            v_tipo;
    END LOOP;
END;
$pruebas$;

ROLLBACK;