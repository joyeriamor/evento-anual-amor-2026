-- Retiro del RPC de ensayo tras entrega real y cierre. No modifica funciones operativas.
DROP FUNCTION IF EXISTS public.whatsapp_ensayo_control_interno(uuid,text,jsonb);
