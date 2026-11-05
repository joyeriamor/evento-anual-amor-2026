-- Deshabilitar WHATSAPP_ENSAYO_PLATAFORMA_HABILITADO antes de retirar la Edge.
-- No borra el historial, las inscripciones ficticias ni medios de Meta automáticamente.
BEGIN;
DROP FUNCTION IF EXISTS public.whatsapp_ensayo_control_interno(uuid,text,jsonb);
-- Conservar tabla de control con RLS y sin permisos directos para conciliar el ensayo.
COMMIT;
