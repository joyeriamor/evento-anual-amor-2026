> Estado vigente: [entrega final del 25 de octubre](ENTREGA_FINAL_FIESTAANUAL26_20261025.md). Este documento conserva la cronología de publicación.

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

## Publicacion frontend completada: 25 de octubre de 2026

El usuario autorizo publicar 43c51c5 y añadir temporalmente la rama exacta feature/chiapas-evento-2026 al entorno github-pages. La ejecucion #15 fue rechazada antes de habilitar la regla; el reintento no creo trabajos y termino con fallo de arranque. Se inicio una ejecucion nueva #16 sobre el mismo commit: https://github.com/joyeriamor/evento-anual-amor-2026/actions/runs/40168327700, completada correctamente en 32 segundos. Inmediatamente se retiro la excepcion; queda solamente main (1 rama y 0 tags), conservando las otras protecciones.

Verificacion HTTP real: inicio RADEV’S, /chiapas/ y /chiapas/acceso/ responden 200; JavaScript y CSS publicados coinciden byte por byte con el candidato probado. Navegador real: RADEV’S muestra evento del 6 de diciembre y registro disponible; Chiapas muestra 19 de diciembre e inscripciones cerradas; acceso Chiapas solicita login. Servidor publico Chiapas devuelve 403 al registro cerrado. Consulta SQL confirma RADEV’S activo/cupo1500 y Chiapas borrador/cupo500.

No se realizo merge a main, no se abrieron inscripciones de Chiapas y no se crearon nuevos datos de ensayo para esta comprobacion publica. Las menciones anteriores a frontend pendiente describen fases previas; este apartado y CIERRE_PUBLICACION_PAGES_20261025.json registran el estado final. El commit documental posterior es local; el sitio publicado corresponde exactamente a 43c51c5.

## Habilitación administrativa autorizada

El usuario designo a hugo como administrador de Chiapas. Se agrego unicamente esa asignacion activa, con comprobacion del perfil administrador activo y cuenta Auth vigente. No se altero perfil ni contraseña. Las asignaciones RADEV’S conservan identica huella antes y despues. El usuario inicio sesion real en Chiapas publicado y se verificaron panel/cupo/usuarios/participantes del evento. No se abrieron inscripciones.
