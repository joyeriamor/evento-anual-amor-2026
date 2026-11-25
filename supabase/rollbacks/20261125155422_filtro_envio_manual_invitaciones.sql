-- Revierte exclusivamente las sobrecargas nuevas; conserva RPC existentes de cuatro argumentos.
DROP FUNCTION IF EXISTS public.bandejas_admin_paginadas(text, integer, text, uuid, text);
DROP FUNCTION IF EXISTS public.bandejas_admin_chiapas_paginadas(text, integer, text, uuid, text);
