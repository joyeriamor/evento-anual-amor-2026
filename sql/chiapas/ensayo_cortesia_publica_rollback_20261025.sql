BEGIN;
SET LOCAL request.jwt.claims='{"sub":"18feeb87-5d99-49b1-8d9b-13c2a3be2117","role":"authenticated"}';
CREATE TEMP TABLE resultado_cortesia(caso text,aprobado boolean) ON COMMIT DROP;
DO $$
DECLARE x jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM registros r JOIN promotoras p ON p.id=r.promotora_id WHERE r.id='d584ec01-b3e9-408c-84be-0ef163304444' AND r.evento_id='3dc92160-79af-4bf7-b770-263038e88900' AND r.folio='EA26-3351CF16A3FD4A0AA390F526B3EF7111' AND p.nombres='PRUEBA PUBLICA APERTURA 20261025' AND p.telefono_whatsapp='0000025102') THEN RAISE EXCEPTION 'Ensayo distinto'; END IF;
 INSERT INTO resultado_cortesia SELECT 'Cortesía pendiente sin QR ni pago',NOT EXISTS(SELECT 1 FROM pagos WHERE registro_id='d584ec01-b3e9-408c-84be-0ef163304444') AND NOT EXISTS(SELECT 1 FROM invitaciones WHERE registro_id='d584ec01-b3e9-408c-84be-0ef163304444');
 x:=public.autorizar_cortesia_admin_chiapas('d584ec01-b3e9-408c-84be-0ef163304444',auth.uid());
 INSERT INTO resultado_cortesia SELECT 'Autorización confirma y exenta',estado='confirmado' AND exento_pago FROM registros WHERE id='d584ec01-b3e9-408c-84be-0ef163304444';
 INSERT INTO resultado_cortesia SELECT 'Autorización emite QR en Vault',EXISTS(SELECT 1 FROM invitaciones i JOIN vault.secrets s ON s.id=i.token_vault_id WHERE i.registro_id='d584ec01-b3e9-408c-84be-0ef163304444' AND i.estado='emitida');
 INSERT INTO resultado_cortesia SELECT 'Cortesía no genera pago ficticio',NOT EXISTS(SELECT 1 FROM pagos WHERE registro_id='d584ec01-b3e9-408c-84be-0ef163304444');
 IF EXISTS(SELECT 1 FROM resultado_cortesia WHERE aprobado IS DISTINCT FROM true) THEN RAISE EXCEPTION 'Fallo de cortesía'; END IF;
END $$;
SELECT * FROM resultado_cortesia;
ROLLBACK;
