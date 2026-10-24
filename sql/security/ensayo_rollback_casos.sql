-- Casos y actores completamente ficticios. No crear usuarios Auth reales.
SELECT set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claim.role','service_role',true);
INSERT INTO pg_temp.usuarios(id,nombre,nombre_usuario,rol) VALUES
 ('00000000-0000-4000-8000-000000000001','PRUEBA ADMIN R','ensayo.admin.r','administrador'),
 ('00000000-0000-4000-8000-000000000002','PRUEBA ADMIN C','ensayo.admin.c','administrador'),
 ('00000000-0000-4000-8000-000000000003','PRUEBA VALID R','ensayo.valid.r','validador'),
 ('00000000-0000-4000-8000-000000000004','PRUEBA VALID C','ensayo.valid.c','validador');
INSERT INTO pg_temp.eventos(id,nombre,estado,fecha_inicio,sede,cuota_fija) VALUES
 ('43e67bda-d19d-4c0e-a639-e85f2d62f294','PRUEBA RADEVS','activo','2026-12-06','FICTICIA',300),
 ('3dc92160-79af-4bf7-b770-263038e88900','PRUEBA CHIAPAS','borrador','2026-12-19','FICTICIA',300);
INSERT INTO pg_temp.configuracion_cupo_evento(evento_id,cupo_maximo) VALUES
 ('43e67bda-d19d-4c0e-a639-e85f2d62f294',1500),('3dc92160-79af-4bf7-b770-263038e88900',500);
INSERT INTO pg_temp.usuarios_eventos(usuario_id,evento_id) VALUES
 ('00000000-0000-4000-8000-000000000001','43e67bda-d19d-4c0e-a639-e85f2d62f294'),
 ('00000000-0000-4000-8000-000000000002','3dc92160-79af-4bf7-b770-263038e88900'),
 ('00000000-0000-4000-8000-000000000003','43e67bda-d19d-4c0e-a639-e85f2d62f294'),
 ('00000000-0000-4000-8000-000000000004','3dc92160-79af-4bf7-b770-263038e88900');
INSERT INTO pg_temp.asesores(id,nombre) VALUES
 ('00000000-0000-4000-8000-000000000010','PRUEBA ASESOR'),('00000000-0000-4000-8000-000000000011','EMPLEADO');
CREATE FUNCTION pg_temp.registrar_ensayo(p_evento uuid,p_tel text,p_tipo text DEFAULT 'vendedora',p_empleado boolean DEFAULT false,p_foto text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql AS $register$
 SELECT pg_temp.crear_registro_publico_v3(p_evento,
 CASE WHEN p_empleado THEN '00000000-0000-4000-8000-000000000011'::uuid ELSE '00000000-0000-4000-8000-000000000010'::uuid END,
 'PRUEBA TEMPORAL','FICTICIA','Chiapas',p_tel,p_tipo,'RUTA FICTICIA',coalesce(p_foto,p_evento::text||'/foto.png'),
 CASE WHEN p_tipo='vendedora' THEN p_evento::text||'/pago.png' END,
 CASE WHEN p_tipo='vendedora' THEN 'CUENTA FICTICIA' END,NULL);
$register$;
DO $casos$
DECLARE
 r constant uuid:='43e67bda-d19d-4c0e-a639-e85f2d62f294';
 c constant uuid:='3dc92160-79af-4bf7-b770-263038e88900';
 ar constant uuid:='00000000-0000-4000-8000-000000000001';
 ac constant uuid:='00000000-0000-4000-8000-000000000002';
 vr constant uuid:='00000000-0000-4000-8000-000000000003';
 vc constant uuid:='00000000-0000-4000-8000-000000000004';
 rr uuid;rc uuid;cr uuid;cc uuid;pr uuid;pc uuid;j jsonb;jr jsonb;jc jsonb;token_anterior text;token_nuevo text;negado boolean;
BEGIN
 -- Confirmar que la identidad de auditoría no utiliza una secuencia pública.
 PERFORM pg_temp.verificar_ensayo('secuencia temporal',
  (SELECT seq.relnamespace=pg_my_temp_schema() FROM pg_class seq WHERE seq.oid=pg_get_serial_sequence('pg_temp.auditoria','id')::regclass));
 j:=pg_temp.registrar_ensayo(r,'5500000001');rr:=(j->>'registro_id')::uuid;
 PERFORM pg_temp.verificar_ensayo('alta RADEVS',j->>'ok'='true');
 j:=pg_temp.registrar_ensayo(c,'5500000001');rc:=(j->>'registro_id')::uuid;
 PERFORM pg_temp.verificar_ensayo('alta Chiapas mismo telefono',j->>'ok'='true' AND rc<>rr);
 PERFORM pg_temp.verificar_ensayo('duplicado por evento',pg_temp.registrar_ensayo(r,'5500000001')->>'codigo'='DUPLICADO');
 PERFORM pg_temp.verificar_ensayo('cuota 300',NOT EXISTS(SELECT 1 FROM pg_temp.pagos WHERE importe<>300));
 negado:=false;BEGIN PERFORM pg_temp.registrar_ensayo(c,'5500000002','promotora',true);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%empleados%';END;
 PERFORM pg_temp.verificar_ensayo('empleado bloqueado Chiapas',negado);
 negado:=false;BEGIN PERFORM pg_temp.registrar_ensayo(c,'5500000003','vendedora',false,r::text||'/ajena.png');EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%otro evento%';END;
 PERFORM pg_temp.verificar_ensayo('archivo ajeno bloqueado',negado);
 j:=pg_temp.registrar_ensayo(r,'5500000004','promotora');cr:=(j->>'registro_id')::uuid;
 j:=pg_temp.registrar_ensayo(c,'5500000005','promotora');cc:=(j->>'registro_id')::uuid;
 PERFORM pg_temp.verificar_ensayo('cortesias sin pagos ficticios',(SELECT count(*)=0 FROM pg_temp.pagos WHERE registro_id IN(cr,cc)));
 SELECT id INTO pr FROM pg_temp.pagos WHERE registro_id=rr;
 SELECT id INTO pc FROM pg_temp.pagos WHERE registro_id=rc;
 PERFORM set_config('request.jwt.claim.sub',vr::text,true);
 jr:=pg_temp.validar_pago_personal(pr,'aprobar',NULL);
 PERFORM pg_temp.verificar_ensayo('validador RADEVS emite QR',jr->>'ok'='true' AND length(jr#>>'{invitacion,token_qr}')=64);
 negado:=false;BEGIN PERFORM pg_temp.validar_pago_personal(pc,'aprobar',NULL);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%no existe%';END;
 PERFORM pg_temp.verificar_ensayo('pago Chiapas invisible en RADEVS',negado);
 PERFORM set_config('request.jwt.claim.sub',vc::text,true);
 jc:=pg_temp.validar_pago_personal_chiapas(pc,'aprobar',NULL);
 PERFORM pg_temp.verificar_ensayo('validador Chiapas emite QR',jc->>'ok'='true' AND length(jc#>>'{invitacion,token_qr}')=64);
 negado:=false;BEGIN PERFORM pg_temp.validar_pago_personal_chiapas(pr,'aprobar',NULL);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%no existe%';END;
 PERFORM pg_temp.verificar_ensayo('pago RADEVS invisible en Chiapas',negado);
 PERFORM set_config('request.jwt.claim.sub','',true);
 j:=pg_temp.recuperar_invitacion_admin_chiapas(rc,ac,false);
 PERFORM pg_temp.verificar_ensayo('recuperar conserva QR',j#>>'{invitacion,token_qr}'=jc#>>'{invitacion,token_qr}');
 negado:=false;BEGIN PERFORM pg_temp.recuperar_invitacion_admin_chiapas(rc,ar,false);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%autorizado%';END;
 PERFORM pg_temp.verificar_ensayo('admin sin asignacion Chiapas bloqueado',negado);
 PERFORM set_config('request.jwt.claim.sub',ac::text,true);
 negado:=false;BEGIN PERFORM pg_temp.consultar_grupo_registro_admin(rr);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%no encontrada%';END;
 PERFORM pg_temp.verificar_ensayo('grupo RADEVS invisible en Chiapas',negado);
 PERFORM pg_temp.verificar_ensayo('grupo propio visible',pg_temp.consultar_grupo_registro_admin(rc)='RUTA FICTICIA');
 PERFORM set_config('request.jwt.claim.sub','',true);
 j:=pg_temp.autorizar_cortesia_admin(cr,ar);
 PERFORM pg_temp.verificar_ensayo('cortesia RADEVS con QR',j->>'ok'='true' AND length(j#>>'{invitacion,token_qr}')=64);
 j:=pg_temp.autorizar_cortesia_admin_chiapas(cc,ac);
 PERFORM pg_temp.verificar_ensayo('cortesia Chiapas con QR',j->>'ok'='true' AND length(j#>>'{invitacion,token_qr}')=64);
 negado:=false;BEGIN PERFORM pg_temp.autorizar_cortesia_admin_chiapas(rc,ac);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%pago validado%';END;
 PERFORM pg_temp.verificar_ensayo('pago validado no convertido a cortesia',negado);
 j:=pg_temp.bandejas_admin_paginadas('invitaciones',1,'',ar);
 PERFORM pg_temp.verificar_ensayo('bandeja RADEVS aislada',(j->>'total')::int=2 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'registros') e WHERE (e->>'registro_id')::uuid IN(rc,cc)));
 j:=pg_temp.bandejas_admin_chiapas_paginadas('invitaciones',1,'',ac);
 PERFORM pg_temp.verificar_ensayo('bandeja Chiapas aislada',(j->>'total')::int=2 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'registros') e WHERE (e->>'registro_id')::uuid IN(rr,cr)));
 token_anterior:=jc#>>'{invitacion,token_qr}';
 j:=pg_temp.recuperar_invitacion_admin_chiapas(rc,ac,true);token_nuevo:=j#>>'{invitacion,token_qr}';
 PERFORM pg_temp.verificar_ensayo('reemision cambia QR',token_nuevo<>token_anterior);
 PERFORM set_config('request.jwt.claim.sub',ar::text,true);
 j:=pg_temp.registrar_entrada_qr_evento(token_nuevo,r);
 PERFORM pg_temp.verificar_ensayo('QR Chiapas rechazado RADEVS',j->>'ok'='false');
 PERFORM set_config('request.jwt.claim.sub',ac::text,true);
 j:=pg_temp.registrar_entrada_qr_evento(token_anterior,c);
 PERFORM pg_temp.verificar_ensayo('QR revocado rechazado',j->>'estado'='no_autorizado');
 j:=pg_temp.registrar_entrada_qr_evento(token_nuevo,c);
 PERFORM pg_temp.verificar_ensayo('entrada Chiapas registrada',j->>'estado'='ingreso_registrado');
 j:=pg_temp.registrar_entrada_qr_evento(token_nuevo,c);
 PERFORM pg_temp.verificar_ensayo('entrada duplicada rechazada',j->>'estado'='ya_ingreso' AND (SELECT count(*)=1 FROM pg_temp.accesos));
 UPDATE pg_temp.usuarios_eventos SET activo=false WHERE usuario_id=ac AND evento_id=c;
 negado:=false;BEGIN PERFORM pg_temp.consultar_qr_acceso_evento(token_nuevo,c);EXCEPTION WHEN OTHERS THEN negado:=SQLERRM ILIKE '%asignacion%';END;
 PERFORM pg_temp.verificar_ensayo('asignacion inactiva rechazada',negado);
 PERFORM pg_temp.verificar_ensayo('estados inscripcion conservados',(SELECT estado='activo' FROM pg_temp.eventos WHERE id=r) AND (SELECT estado='borrador' FROM pg_temp.eventos WHERE id=c));
 PERFORM pg_temp.verificar_ensayo('cupos separados conservados',(SELECT cupo_maximo=1500 FROM pg_temp.configuracion_cupo_evento WHERE evento_id=r) AND (SELECT cupo_maximo=500 FROM pg_temp.configuracion_cupo_evento WHERE evento_id=c));
 PERFORM pg_temp.verificar_ensayo('hashes QR correctos',NOT EXISTS(SELECT 1 FROM pg_temp.invitaciones i JOIN pg_temp.secretos_ensayo s ON s.id=i.token_vault_id WHERE i.token_hash<>encode(sha256(convert_to(s.decrypted_secret,'UTF8')),'hex')));
 PERFORM pg_temp.verificar_ensayo('funciones public y ACL sin cambios',
  (SELECT huella FROM pg_temp.catalogo_antes_ensayo) IS NOT DISTINCT FROM
  (SELECT md5(string_agg(p.oid::text||pg_get_functiondef(p.oid)||coalesce(p.proacl::text,''),'|' ORDER BY p.oid))
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f'));
 IF (SELECT count(*) FROM pg_temp.resultados_ensayo)<>31 THEN RAISE EXCEPTION 'Numero inesperado de casos'; END IF;
END;
$casos$;
ROLLBACK;
SELECT 'APROBADO' resultado,31 casos,
 to_regclass('pg_temp.resultados_ensayo') IS NULL AS rollback_sin_tablas_de_ensayo,
 'Solo pg_temp y datos ficticios; Vault simulado; sin Auth/Storage ni escrituras en public' alcance;
