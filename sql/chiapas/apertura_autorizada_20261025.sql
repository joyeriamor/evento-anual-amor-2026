-- Autorizado por el usuario: abrir únicamente Chiapas, 25/10/2026.
-- El servidor también requiere REGISTROS_CHIAPAS_HABILITADOS=true.
BEGIN;
SET LOCAL lock_timeout = '2s';
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.eventos WHERE id='3dc92160-79af-4bf7-b770-263038e88900' AND estado='borrador' AND sede='Tuxtla Gutiérrez, Chiapas (salón por definir)') THEN
    RAISE EXCEPTION 'Estado de Chiapas distinto del revisado; no aplicar automáticamente';
  END IF;
END $$;
UPDATE public.eventos SET sede='SALÓN BLANCO, Tuxtla Gutiérrez, Chiapas', estado='activo'
WHERE id='3dc92160-79af-4bf7-b770-263038e88900';
COMMIT;
