-- Approved fictitious Chiapas probe only. Never apply as a migration.
-- No public/auth/storage DML or DDL; reads/decrypts only its own new Vault ID.
BEGIN;
SET LOCAL statement_timeout='20s';
SET LOCAL lock_timeout='1s';
DO $vault_probe$
DECLARE
 v_name CONSTANT text := 'ensayo-chiapas-vault-f58668df-cd1a-4583-9262-d6c0432fd544';
 v_id uuid;
 v_plain text := gen_random_uuid()::text || gen_random_uuid()::text;
 v_rotated text := gen_random_uuid()::text || gen_random_uuid()::text;
 v_encrypted text;
 v_new_encrypted text;
 v_recovered text;
BEGIN
 IF EXISTS(SELECT 1 FROM vault.secrets WHERE name=v_name) THEN
  RAISE EXCEPTION 'Nombre de ensayo ya existe: abortar sin modificarlo';
 END IF;
 v_id := vault.create_secret(v_plain,v_name,'Ficticio Chiapas; ROLLBACK obligatorio',NULL);
 IF v_id IS NULL THEN RAISE EXCEPTION 'No se creo secreto ficticio'; END IF;
 SELECT secret INTO STRICT v_encrypted FROM vault.secrets WHERE id=v_id AND name=v_name;
 IF v_encrypted IS NULL OR v_encrypted=v_plain THEN RAISE EXCEPTION 'Cifrado no verificado'; END IF;
 SELECT decrypted_secret INTO STRICT v_recovered FROM vault.decrypted_secrets WHERE id=v_id;
 IF v_recovered IS DISTINCT FROM v_plain THEN RAISE EXCEPTION 'Recuperacion no verificada'; END IF;
 PERFORM vault.update_secret(v_id,v_rotated,v_name,'Ficticio Chiapas actualizado; ROLLBACK obligatorio',NULL);
 SELECT decrypted_secret INTO STRICT v_recovered FROM vault.decrypted_secrets WHERE id=v_id;
 IF v_recovered IS DISTINCT FROM v_rotated OR v_recovered=v_plain THEN RAISE EXCEPTION 'Actualizacion no verificada'; END IF;
 SELECT secret INTO STRICT v_new_encrypted FROM vault.secrets WHERE id=v_id AND name=v_name;
 IF v_new_encrypted IS NULL OR v_new_encrypted=v_rotated OR v_new_encrypted=v_encrypted THEN RAISE EXCEPTION 'Nuevo cifrado no verificado'; END IF;
END;
$vault_probe$;
ROLLBACK;
SELECT 'APROBADO' AS resultado,6 AS comprobaciones,
 NOT EXISTS(SELECT 1 FROM vault.secrets WHERE name='ensayo-chiapas-vault-f58668df-cd1a-4583-9262-d6c0432fd544') AS rollback_sin_secreto_ficticio,
 'Solo secreto ficticio de Chiapas; sin QR ni datos reales; Vault real' AS alcance;
