# Publicación backend del 24 de octubre de 2026

Autorización explícita del usuario: etapas 01 Chiapas, 02 compartida, 03 RADEV’S, 24 Edge y pruebas ficticias con limpieza. Frontend aún sin publicar; Chiapas cerrado.

Se aplicaron las tres etapas (versiones servidor 20261025031017, 20261025031024 y 20261025031032). Las 24 definiciones SQL esperadas coinciden con el paquete. Las 24 Edge activas se descargaron y compararon íntegramente con los archivos locales; JWT conserva configuración prevista. 20 endpoints privados rechazaron sin sesión (401); registro público Chiapas rechazó cerrado (403): 21/21 solicitudes HTTP reales.

La cuenta ficticia creada por el usuario tuvo perfil administrador únicamente en Chiapas; se elimino al finalizar. Inicio de sesión real y panel: correctos. Registro vendedora ficticia con foto y comprobante sintéticos creado y marcado es_prueba; cupo permanece 500 disponibles. No transferencia real ni modificación de participantes reales.

El ensayo detectó que la nueva Edge llamaba al RPC exclusivo RADEV’S. Se corrigió creando crear_registro_prueba_admin_chiapas, restringido a service_role y al UUID Chiapas; se conserva intacto crear_registro_prueba_admin_v2 de RADEV’S. Migración fuente 20261025031900_registro_prueba_independiente_chiapas.sql; rollback dedicado sql/chiapas/rollback_registro_prueba_independiente.sql. Edge Chiapas versión 2. 84 comprobaciones de integración catalogada y 236 de aislamiento locales aprobadas. Auth/Storage/Vault locales son adaptadores, no servicios remotos.

La ficha permite localhost:5173; el servidor de ensayo se corrigió a ese origen sin ampliar CORS. La verificacion posterior figura abajo. El frontend publico sigue sin publicar.

Los intentos anteriores revertidos y los bloqueos de aprobación se conservan en el historial, no se eliminan. Respaldos en RESPALDO_PUBLICACION_20261024.local, excluido de Git. No ejecutar db push desde raíz: contiene ruta consolidada alternativa. Estas migraciones ya están aplicadas; no volver a ejecutarlas.

## Verificación posterior

Batería local completa aprobada después de la corrección: lint, TypeScript, build, Deno, 236 aislamiento, 84 integración catalogada, 46+46 etapas, 13 E2E con backend simulado y 21 estático con red externa bloqueada, además de baterías previas.

HTTP real con sesión: administrador Chiapas autorizado; 19 solicitudes dirigidas a RADEV’S rechazadas 403; alta multipart Chiapas rechaza JSON 415 sin escritura (no demuestra por sí sola autorización por evento); lectura directa registros rechazada 403 por permisos de tabla, sin atribuirla erróneamente a RLS; archivo privado ficticio existente sin firma rechazado 400. El primer arnés esperaba erróneamente 403 para multipart y 200/[] para SELECT: se conservan sus resultados y se documenta interpretación correcta, sin alterar código para satisfacer expectativas.

Siete ensayos reales Auth/Vault/acceso aprobados: recuperación mismo token, consulta autorizable, reemisión token distinto, revocación anterior, rechazo de ingreso en RADEV’S, ingreso ficticio Chiapas y rechazo de duplicado. Tokens y contraseñas no guardados en evidencias.

Pruebas SQL reales adicionales con ROLLBACK: asignación ficticia inactiva rechaza consulta QR, asignación restaurada activa al terminar; cortesía ficticia pendiente sin pago ni invitación, autorización con QR de Vault y exención confirmada; rollback verificado sin promotora de ensayo residual. Estas pruebas fijan claims de SQL explícitamente: son integración SQL real, no un nuevo inicio de sesión Auth ni E2E de la cortesía.

## Cierre y entrega

Usuario autorizo eliminar unicamente el ensayo. Se eliminaron mediante Storage los dos objetos exactos de fotos-promotoras y comprobantes-pago, sin borrar carpetas ni otros archivos. Transaccion SQL con comprobaciones de identidad elimino registro, promotora, pago, dos invitaciones, acceso, dos secretos Vault, tres entradas de auditoria propias, perfil y asignacion. La cuenta Auth ficticia se elimino desde el panel. Verificacion final: cero elementos de todos esos tipos y cero sesiones; permanecen las cuatro cuentas previas. Sesion local cerrada. RADEV’S activo, cupo 1500; Chiapas borrador, cupo 500.

Limitacion de cobertura: no se inicio sesion real como un operador RADEV’S para probar RADEV’S hacia Chiapas; ese sentido se cubrio mediante pruebas locales/SQL de autorizacion. La cortesia y asignacion inactiva se ensayaron en SQL real con claims explicitos y ROLLBACK, no como E2E del navegador. No se afirma aislamiento absoluto entre infraestructuras: ambos eventos comparten proyecto Supabase.

Advisores revisados: las tablas internas sin politicas permanecen cerradas; existen avisos de funciones SECURITY DEFINER (incluidos triggers heredados y RPC intencionales con controles de identidad). La proteccion Auth contra contraseñas filtradas esta deshabilitada desde antes; no se cambio configuracion global.

Plan de frontend: subir la rama feature/chiapas-evento-2026 desde la VM con la cuenta GitHub correcta; verificar que incluya los commits b2a812a, a0204c3, 5959422 y el cierre posterior. Publicar Pages solo tras autorizacion de frontend usando workflow_dispatch sobre esa rama; no merge a main. Compilar con las tres variables publicas del proyecto y VITE_REGISTROS_HABILITADOS=true como contrato existente; mantener cerrado el interruptor servidor de Chiapas. No publicar el dist generado por pruebas con claves ficticias ni aplicar de nuevo migraciones ya instaladas. Tras publicar: comprobar rutas directas /chiapas/ y /chiapas/acceso/, carga de assets y que las inscripciones sigan cerradas.
