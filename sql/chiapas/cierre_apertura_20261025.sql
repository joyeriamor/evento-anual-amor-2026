-- Cierre reversible de Chiapas. Antes, poner REGISTROS_CHIAPAS_HABILITADOS=false.
-- No elimina inscripciones ni altera RADEV’S. Conserva la sede confirmada.
BEGIN;
SET LOCAL lock_timeout = '2s';
UPDATE public.eventos SET estado='borrador'
WHERE id='3dc92160-79af-4bf7-b770-263038e88900' AND estado='activo';
COMMIT;
