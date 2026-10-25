BEGIN;
SET LOCAL request.jwt.claims = '{"sub":"18feeb87-5d99-49b1-8d9b-13c2a3be2117","role":"authenticated"}';
CREATE TEMP TABLE resultado_apertura(caso text,aprobado boolean) ON COMMIT DROP;
DO $$
DECLARE a jsonb;b jsonb;n jsonb;t text;u text;x jsonb;bloqueado boolean:=false;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.registros WHERE id='2d25dbc3-e10f-4dd0-b460-8ae45e9688b2' AND es_prueba AND evento_id='3dc92160-79af-4bf7-b770-263038e88900') THEN RAISE EXCEPTION 'Ensayo no identificado'; END IF;
 a:=public.recuperar_invitacion_admin_chiapas('2d25dbc3-e10f-4dd0-b460-8ae45e9688b2',auth.uid(),false);
 b:=public.recuperar_invitacion_admin_chiapas('2d25dbc3-e10f-4dd0-b460-8ae45e9688b2',auth.uid(),false);
 t:=a->'invitacion'->>'token_qr';
 INSERT INTO resultado_apertura VALUES('Vault: recuperación conserva QR',length(t)=64 AND t=b->'invitacion'->>'token_qr');
 n:=public.recuperar_invitacion_admin_chiapas('2d25dbc3-e10f-4dd0-b460-8ae45e9688b2',auth.uid(),true);
 u:=n->'invitacion'->>'token_qr';
 INSERT INTO resultado_apertura VALUES('Reemisión cambia QR',length(u)=64 AND u<>t);
 x:=public.consultar_qr_acceso_evento(t,'3dc92160-79af-4bf7-b770-263038e88900');
 INSERT INTO resultado_apertura VALUES('QR anterior no autorizable',x->>'estado'<>'autorizable');
 BEGIN
 x:=public.registrar_entrada_qr_evento(u,'43e67bda-d19d-4c0e-a639-e85f2d62f294');
 bloqueado:=COALESCE(x->>'estado','')<>'ingreso_registrado';
 EXCEPTION WHEN OTHERS THEN bloqueado:=true; END;
 INSERT INTO resultado_apertura VALUES('QR Chiapas rechazado en RADEVS',bloqueado);
 x:=public.registrar_entrada_qr_evento(u,'3dc92160-79af-4bf7-b770-263038e88900');
 INSERT INTO resultado_apertura VALUES('Entrada Chiapas correcta',x->>'estado'='ingreso_registrado');
 x:=public.registrar_entrada_qr_evento(u,'3dc92160-79af-4bf7-b770-263038e88900');
 INSERT INTO resultado_apertura VALUES('Doble entrada bloqueada',x->>'estado'='ya_ingreso');
 IF EXISTS(SELECT 1 FROM resultado_apertura WHERE aprobado IS DISTINCT FROM true) THEN RAISE EXCEPTION 'Fallo en prueba'; END IF;
END $$;
SELECT * FROM resultado_apertura;
ROLLBACK;
