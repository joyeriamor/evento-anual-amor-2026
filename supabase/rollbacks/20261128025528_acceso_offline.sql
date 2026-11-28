-- Ejecutar solo tras sincronizar todos los pendientes y retirar la Edge nueva.
-- No borra ni revierte accesos ya recibidos ni modifica las funciones existentes.
DROP FUNCTION IF EXISTS public.offline_sincronizar(uuid,uuid,uuid,uuid,text,timestamptz);
DROP FUNCTION IF EXISTS public.offline_descargar(uuid,uuid);
DROP FUNCTION IF EXISTS public.offline_autorizar(uuid);
DROP TABLE IF EXISTS public.offline_operaciones;
DROP TABLE IF EXISTS public.offline_paquetes;
