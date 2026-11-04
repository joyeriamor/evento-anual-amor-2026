-- Solo tras detener el worker y conservar la bitácora/medios para conciliación.
-- No borra tablas existentes, invitaciones, pagos, consentimiento ni historial.
BEGIN;
DROP FUNCTION IF EXISTS public.whatsapp_guardar_medio_interno(uuid,uuid,text);
DROP FUNCTION IF EXISTS public.whatsapp_marcar_medio_eliminado_interno(uuid,uuid,text);
DROP FUNCTION IF EXISTS public.whatsapp_reservar_limpieza_interno();
DROP FUNCTION IF EXISTS public.whatsapp_finalizar_limpieza_interno(uuid,uuid,text);
DROP FUNCTION IF EXISTS public.whatsapp_preparar_admin_interno(uuid,uuid,boolean);
DROP FUNCTION IF EXISTS public.whatsapp_qr_admin_interno(uuid,uuid);
DROP FUNCTION IF EXISTS public.whatsapp_confirmar_entrega_interno(text,text,timestamptz);
DROP FUNCTION IF EXISTS public.whatsapp_conciliar_entrega_interno(text);
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
