# FIESTAANUAL26 — desarrollo local y verificación

Fecha: 24 de octubre de 2026. Rama: `feature/chiapas-evento-2026`.
Base verificada: `8113458`, precedida de `645292d` y `53c1661`.
Repositorio original: `C:\PROYECTOS\FIESTAANUAL26`, accesible por SMB en `/Volumes/Proyectos/FIESTAANUAL26`.

## Alcance y estado

Se continuó el código existente, incluidos los cambios locales recibidos. Se preservaron los respaldos `.bak`, archivos sin seguimiento, configuración de publicación y variables de entorno. Las funciones originales estaban excluidas por `supabase/` en `.gitignore`; se añaden explícitamente los fuentes necesarios, sin añadir configuraciones ni secretos.

**El desarrollo local tiene verificaciones aprobadas. No se declara listo para producción:** falta ensayar contra una instancia Supabase desechable con el esquema y las políticas reales, Vault y las funciones desplegadas. No se modificó ninguna base remota, función publicada ni estado de inscripción. No hubo despliegue, push ni merge.

## Funcionalidades y controles implementados

- Selección pública entre RADEV'S Minatitlán y Chiapas mediante rutas separadas. Los paneles recuperan sesión y rol para el evento seleccionado.
- Listados, ficha, comprobantes, pagos, cortesías, recuperación y reemisión de QR, bandejas de personal, historial, cupo y usuarios envían el contexto de evento correspondiente. Los endpoints específicos de Chiapas se seleccionan automáticamente.
- Fechas y sede de las invitaciones corresponden al evento: 6 de diciembre de 2026 / RADEV'S, y 19 de diciembre de 2026 / Chiapas. No se inventa sede u horario para Chiapas.
- Se conservan los formularios y reglas de registro existentes. Chiapas continúa bloqueado en frontend y cerrado por defecto en backend. No se alteró la configuración real de inscripciones de RADEV'S.
- La capa común `supabase/functions/_shared/evento.ts` valida el JWT contra Auth, el perfil y rol activos y la asignación activa de `usuarios_eventos`, antes del handler privado. Rechaza métodos, JSON inválido, eventos desconocidos y cuerpos excesivos, incluso sin Content-Length.
- Se ignoran identificadores administrativos del navegador. El contexto interno de evento se sobrescribe siempre en servidor. Los endpoints RADEV'S y Chiapas específicos fijan su UUID en servidor; los endpoints comunes aceptan solo los dos UUID conocidos, y verifican la asignación del solicitante al evento elegido.
- Los endpoints de pago e invitación comprueban la pertenencia del objeto antes de llamar a la RPC. Listados, detalle, comprobantes e historial filtran por evento antes de consultar relaciones o firmar archivos.
- `gestionar-usuarios` lista únicamente miembros activos del evento, asigna las cuentas nuevas a ese evento y rechaza editar cuentas compartidas activas con otro evento. Esto protege el perfil y la contraseña globales de cuentas compartidas. El control del último administrador se limita al evento seleccionado.
- El login por nombre de usuario comprueba la asignación activa antes de entregar los tokens; la contraseña se valida mediante Auth. El registro legacy mantiene su cierre y fija RADEV'S en servidor.
- Los clientes Supabase de Edge quedan fijados a `2.117.3`, versión utilizada por el proyecto.

Endpoints privados revisados: `validar-pago`, `administrar-invitacion`, `bandejas-admin`, `bandeja-personal`, sus cuatro variantes Chiapas, `listar-participantes`, `detalle-participante`, `consultar-acceso`, `consultar-acceso-evento`, `resumen-accesos`, `gestionar-usuarios`, `registrar-prueba-admin`, `resumen-cupo-evento` y `verificar-personal`. Se revisaron también login, catálogo público de asesores y los registros públicos. El catálogo conserva su contrato público reducido de asesores activos.

## SQL preparado, sin ejecutar en producción

`sql/security/` contiene propuestas locales, no migraciones aplicadas:

- `radevs_administracion_propuesta.sql`: conserva firmas y lógica existente, añade identidad/rol/asignación y limita ejecución a service_role. Conserva verificaciones previas de la definición esperada.
- `radevs_personal_propuesta.sql`: exige asignación activa a RADEV'S para validadores.
- `radevs_bandejas_propuesta.sql`: búsqueda, conteo y paginación por RADEV'S, con asignación activa y permisos restringidos.
- `qr_eventos_propuesta.sql`: consulta y entrada ligadas al evento y al operador activo. Rechaza QR de otro evento. Bloquea la inscripción y vuelve a leer la invitación después del bloqueo, para evitar usar una versión anterior a una revocación concurrente.
- `rls_storage_propuesta.sql`: políticas restrictivas que intersectan las políticas permisivas existentes; filtran lecturas por asignación y rol, bloquean lectura anónima de tablas privadas y escrituras directas del cliente. Restringen fotos y comprobantes por relación con la inscripción. Exigen buckets privados.
- `respaldo_previo_lectura.sql`: catálogo de definiciones, ACL, políticas, flags RLS y visibilidad de buckets para preparar un respaldo y detectar RPC no versionadas.
- `rollback_rls_storage.sql`: retira únicamente las políticas nuevas. La restauración exacta de flags RLS, visibilidad de buckets, funciones y permisos requiere el respaldo previo; no se adivina el estado anterior de producción.

Se conservan las propuestas y ensayos previos de `sql/chiapas/`, incluidas las funciones de pago y QR Chiapas y los wrappers legacy. No se generó un nombre ficticio de migración Supabase: la CLI no está disponible. Antes del despliegue deben convertirse en una secuencia de migración revisada mediante la CLI del entorno de destino.

## Resultados de verificación

| Verificación | Resultado | Límite de la evidencia |
|---|---:|---|
| Pruebas existentes de administración Chiapas | 17/17 | Handler real, dependencias Supabase simuladas |
| Pruebas existentes de bandejas admin Chiapas | 14/14 | Handler real, dependencias Supabase simuladas |
| Pruebas existentes de bandeja personal Chiapas | 19/19 | Incluye cero comprobantes RADEV'S firmados; backend simulado |
| Pruebas legacy de acceso Chiapas | 8/8 | Handler real, backend simulado |
| Matriz nueva de aislamiento | 197 aprobadas | 17 endpoints; backend simulado; dos solicitudes con transporte HTTP real en localhost |
| SQL en PostgreSQL embebido PGlite 0.5.11 | 33 aprobadas | Motor PostgreSQL real, esquema y datos sintéticos, sin servicio Supabase/Vault |
| E2E en Chrome con Playwright 1.62.1 | 10 aprobadas | Navegador real; respuestas HTTP de Supabase simuladas; no equivale a E2E contra un backend real |
| TypeScript frontend | Aprobado | `tsc -b` |
| Build Vite | Aprobado | Vite 8.3.4; entorno local |
| Lint | Aprobado | `eslint .`; se excluyen duplicados y respaldos, conservados en disco |
| Sintaxis Edge | 23 archivos comprobados | Transpilación TypeScript; no equivale a `deno check` |

Las pruebas SQL ejecutan los cuerpos reales de las funciones y sus ACL. En el esquema vacío de prueba se omiten únicamente los bloques que comparan hashes con definiciones de producción inexistentes. Se comprueban filtros de bandejas, pagos cruzados, asignaciones desactivadas, rechazo de pagos con ROLLBACK, QR ajenos, entrada única, cuentas inactivas y políticas RLS frente a permisos deliberadamente amplios de las tablas ficticias. También se prueba el rollback de políticas. No se probó concurrencia multisesión ni cifrado/recuperación real de Vault.

Las pruebas anteriores se adaptaron al nuevo punto de entrada: sus unidades aíslan el handler legacy; la matriz nueva ejecuta la capa de autorización real y el handler. No se presenta un mock como una solicitud real a Supabase.

## Reproducción

Con las dependencias del proyecto instaladas, `npm run test:security` ejecuta las tres suites previas y la matriz nueva. `node scripts/test-edge-acceso-chiapas.cjs` ejecuta la suite legacy de acceso.

Las verificaciones opcionales necesitan herramientas de prueba externas, no dependencias de la aplicación publicada:

- SQL: proporcionar PGlite `0.5.11` mediante `PGLITE_MODULE` (ruta absoluta a su módulo) o instalarlo en el entorno de pruebas; ejecutar `npm run test:sql`.
- E2E: proporcionar Playwright `1.62.1` mediante `PLAYWRIGHT_MODULE`; usar un navegador de prueba instalado o `FIESTA_CHROME_PATH`. Levantar Vite con `VITE_SUPABASE_URL=http://127.0.0.1:54321` y una clave ficticia `VITE_SUPABASE_PUBLISHABLE_KEY=local-test-only`, sin copiar credenciales reales. Ejecutar `npm run test:e2e`. El script rechaza destinos distintos de localhost.
- Para repetir lint y compilación: `npm run lint` y `npm run build`.

En esta sesión las dependencias de macOS se instalaron en una carpeta temporal a partir de package-lock; no se sustituyó node_modules de Windows. Las herramientas opcionales no se incorporaron al bundle de la aplicación.

## Pendientes y plan de despliegue, sujeto a aprobación explícita

1. Obtener por el canal autorizado un export completo del esquema, políticas, grants, funciones/RPC y configuración de buckets. El repositorio no contiene todo el catálogo desplegado. Ejecutar el inventario de lectura y comparar los hashes; abortar ante cualquier diferencia no revisada.
2. Preparar una instancia Supabase desechable con ese esquema, Auth y Vault reales y usuarios ficticios: administradores y personal de un solo evento, ambos eventos, sin asignación y desactivados. No reutilizar datos personales de producción.
3. Ensayar migraciones y rollback. Verificar cada SECURITY DEFINER y ACL del catálogo completo; resolver políticas existentes que interfieran con las propuestas. Confirmar que FOTO_BUCKET corresponde al bucket revisado y no es público. Probar almacenamiento y URLs firmadas reales, cupos 1500/500, reglas de cortesía, cuota $300 y registro cerrado.
4. Ejecutar `deno check`, pruebas de Edge en runtime Deno/Supabase y E2E contra ese backend. Probar aprobación con Vault, recuperación/reemisión real, QR antiguos y simultaneidad de pago, revocación y entrada. Faltan credenciales y un entorno Supabase desechable para estas pruebas; no se usó producción como sustituto.
5. Revisar los commits y las migraciones definitivas. Respaldar definiciones, ACL, políticas y configuración vigentes. **Solicitar aprobación explícita antes de cualquier aplicación o despliegue a producción.**
6. Con aprobación, instalar SQL y dependencias en orden: protecciones y funciones por evento, QR por evento, wrappers legacy, bandejas y políticas revisadas; publicar Edge junto con `_shared`; después publicar frontend. No habilitar registros como parte de ese despliegue. Cualquier apertura requiere una aprobación independiente.
7. Comprobar primero RADEV'S con cuentas y registros de prueba autorizados, luego Chiapas; comparar métricas y errores. Ante regresión, restaurar funciones y ACL exactas del respaldo y la versión anterior del frontend/Edge. Retirar políticas nuevas con el rollback preparado y restaurar flags/configuración desde el respaldo.

Hasta completar estos pasos, las pruebas locales no prueban el aislamiento de todas las RPC actualmente publicadas ni autorizan operar Chiapas en producción.
