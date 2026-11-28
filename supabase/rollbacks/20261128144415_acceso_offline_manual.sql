-- Primero sincronizar/resguardar pendientes por nombre y retirar acceso-offline-manual.
-- No elimina accesos ya recibidos ni cambia el módulo QR anterior.
DROP FUNCTION public.offline_sincronizar_manual(uuid,uuid,uuid,uuid,uuid,uuid,timestamptz,boolean);
