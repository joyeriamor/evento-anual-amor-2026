-- Solo tras detener el worker y conservar la bitácora/medios para conciliación.
-- No borra tablas existentes, invitaciones, pagos, consentimiento ni historial.
BEGIN;
DROP FUNCTION IF EXISTS public.whatsapp_confirmar_entrega_interno(text,text,timestamptz);
DROP TRIGGER whatsapp_invitacion_confirmada ON public.invitaciones;
DROP TRIGGER whatsapp_registro_confirmado ON public.registros;
DROP FUNCTION public.whatsapp_admin_interno(uuid,uuid,text,uuid,integer);
DROP FUNCTION public.whatsapp_autorizar_salida_interno(uuid,uuid);
DROP FUNCTION public.whatsapp_finalizar_interno(uuid,uuid,text,text,text);
DROP FUNCTION public.whatsapp_reservar_interno(text);
DROP FUNCTION public.whatsapp_al_confirmar_interno();
DROP FUNCTION public.whatsapp_encolar_interno(uuid);
DROP FUNCTION public.whatsapp_contexto_interno(uuid);
-- Columnas y fases se conservan para no perder evidencia de intentos o resultados inciertos.
COMMIT;
