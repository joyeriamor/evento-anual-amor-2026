-- PROPUESTA LOCAL. NO EJECUTAR EN PRODUCCION SIN PRUEBAS.
-- RADEV'S mantiene las firmas originales.
-- Todas las consultas y entradas pasan por validacion por evento.

BEGIN;

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