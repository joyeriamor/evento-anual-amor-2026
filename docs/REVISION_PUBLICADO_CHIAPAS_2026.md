# Comparación con Supabase publicado — revisión sin despliegue

24 de octubre de 2026. Base local `31e72d6`, rama `feature/chiapas-evento-2026`.

## Alcance y evidencia

Se recuperaron en modo lectura el código de las 17 Edge Functions activas y el catálogo SQL, sin invocar endpoints de negocio ni leer comprobantes, tokens QR o secretos. `AUDITORIA_PUBLICADO_20261024.json` guarda hashes de código y el resultado de la comparación estructural, no credenciales ni datos de participantes. El script `scripts/comparar-publicado-local.mjs` compara exportaciones proporcionadas como archivos; no conecta a Supabase.

El catálogo coincide con los snapshots de pruebas: 29 funciones públicas con sus firmas, hashes, ACL y SECURITY DEFINER; 13 tablas con flags y privilegios; 83 columnas; 43 restricciones; 4 triggers; 2 políticas; 29 índices; 6 extensiones; 2 buckets privados. No se detectó drift en estos elementos. Esto acredita compatibilidad de la base estructural, no integración funcional ni ausencia absoluta de fallos.

Las 17 Edge publicadas difieren de la versión local. Ninguna contiene una consulta directa a usuarios_eventos en el código recuperado; la revisión de los handlers confirma que la validación original de rol no proporciona por sí sola asignación por evento. No se explotaron rutas con datos reales para comprobar esas carencias. Las verificaciones de objeto, SQL y Storage dependen además de las protecciones propuestas, todavía sin publicar.

## Inventario y contratos revisados

| Función publicada | Versión | verify_jwt actual | RPC utilizadas por versión local |
|---|---:|---|---|
| probar-limite-registro | 6 | true | comprobar_limite_registro |
| verificar-admin | 6 | true | Consultas directas |
| listar-participantes | 7 | true | Consultas directas |
| detalle-participante | 8 | true | Consultas directas |
| validar-pago | 10 | true | validar_pago_admin |
| administrar-invitacion | 8 | true | autorizar_cortesia_admin, recuperar_invitacion_admin |
| consultar-acceso | 7 | true | consultar_qr_acceso |
| resumen-accesos | 6 | true | Consultas directas |
| bandejas-admin | 6 | true | bandejas_admin_paginadas |
| gestionar-usuarios | 9 | true | crear_perfil_evento_interno |
| verificar-personal | 7 | true | Consultas directas |
| bandeja-personal | 6 | true | Consultas directas |
| iniciar-sesion-usuario | 10 | false | comprobar_limite_login |
| registrar-participante-v2 | 9 | false | comprobar_limite_registro, crear_registro_publico_v3 |
| listar-asesores-registro | 6 | false | Consultas directas |
| registrar-prueba-admin | 7 | true | crear_registro_prueba_admin_v2 |
| resumen-cupo-evento | 6 | true | resumen_cupo_evento_interno |

Revisión de contratos y diferencias que requieren una entrega coordinada:

- `bandejas-admin`: la publicada consulta varias tablas con límite 1000 y pagina en memoria; la local usa `bandejas_admin_paginadas`. Conserva `tipo`, `total`, `pagina`, `limite`, `registros` y `limitado`; requiere publicar previamente la RPC protegida. No sustituir la local por la publicada al preparar el bundle.
- `gestionar-usuarios`: conserva acciones y respuestas, pero añade la RPC atómica `crear_perfil_evento_interno`, filtra asignaciones y devuelve 409 al intentar editar perfiles globales compartidos. La creación requiere la etapa compartida instalada; la recuperación de fallos de Auth sigue pendiente de prueba real.
- `validar-pago` y `administrar-invitacion`: mantienen los nombres de RPC y contratos de acciones existentes; incorporan guard y comprobación del evento del recurso antes de ejecutar la operación. Los cambios de seguridad SQL deben aprobarse junto con las Edge originales.
- `listar-participantes`, `detalle-participante`, `resumen-accesos` y `bandeja-personal`: las consultas locales se restringen al evento autorizado. Los comprobantes se firman solo tras comprobar pertenencia. Son consultas privilegiadas en servidor: instalar solo RLS no protege automáticamente su uso de service_role.
- `consultar-acceso`: conserva el nombre legacy y su RPC. Chiapas utiliza la nueva `consultar-acceso-evento`, aún sin publicar; sus RPC y wrappers requieren las etapas compartida y RADEV’S según el paquete. No publicar un frontend que invoque un endpoint inexistente.
- `verificar-personal`, `iniciar-sesion-usuario` y `resumen-cupo-evento`: el contexto local incorpora evento autorizado; el valor por omisión legacy sigue siendo RADEV’S. El login público conserva su protección de límite de intentos y no se transforma en endpoint privado. Los rechazos por falta de asignación son un cambio intencional de autorización.
- `registrar-participante-v2` y `registrar-prueba-admin`: conservan sus RPC existentes. Las versiones locales y SQL fijan el contexto y validan archivos/cupo; la inscripción pública Chiapas sigue cerrada. `listar-asesores-registro` sigue siendo catálogo público, sin acceso administrativo.

La comparación estática no demuestra que todas las respuestas de las versiones publicadas y locales sean idénticas para todos los casos. Los contratos críticos anteriores se revisaron contra el código y las pruebas locales existentes; la compatibilidad real con Auth, Storage, Vault y el frontend publicado continúa pendiente.

## Dos rutas antiguas recuperadas y protegidas localmente

`verificar-admin` y `probar-limite-registro` existían en Supabase pero no tenían un index.ts local en el paquete. Se incorporaron a partir del código publicado, conservando sus respuestas y lógica y fijando el SDK. No se reemplazó una versión local avanzada.

- `verificar-admin`: usa ahora el guard común de JWT, administrador activo y asignación activa al evento; conserva la respuesta `autorizado` y `usuario` y la restricción de origen del handler. La respuesta de OPTIONS/métodos inválidos pasa por el guard común; no se amplían sus permisos de operación.
- `probar-limite-registro`: es una herramienta de prueba, ahora restringida a administrador activo asignado a RADEV’S. Su HMAC usa el prefijo `prueba:registro:<evento>:ip:` para no consumir el contador de inscripción real `registro:ip:`. No se ejecutó contra Supabase. Esta restricción es deliberada: el JWT del gateway por sí solo no constituye autorización administrativa.

Ambas quedan pendientes de autorización para sustituir las funciones publicadas. La matriz local cubre 19 endpoints privados, incluidos rechazos antes de consultar la RPC y casos positivos de las dos rutas recuperadas.

## Bloqueos concretos de publicación

Consultas agregadas de solo lectura encontraron RADEV’S en estado `activo` y Chiapas en `borrador`. Hay dos administradores y una cuenta de acceso activos asignados a RADEV’S; no se encontraron asignaciones activas de perfiles activos para Chiapas. Existe además **un perfil activo sin ninguna asignación activa**. No se consultaron ni documentaron identidades personales ni se cambió ninguna asignación.

Antes de publicar guards o login hay que revisar ese perfil con el responsable y decidir explícitamente a qué evento corresponde o si debe permanecer sin acceso. No inferir ni asignar RADEV’S por omisión: puede bloquear una cuenta actualmente usada, y la ausencia de asignación no acredita que deba recibir permisos. También falta provisionar las identidades ficticias Chiapas mediante acceso administrativo seguro.

Los siete endpoints solo locales son las cinco variantes Chiapas, `consultar-acceso-evento` y `registrar-participante`. Este último es utilizado por páginas de prueba existentes; no debe publicarse automáticamente solo por existir en el directorio. Revisar si esas páginas y ese endpoint deben formar parte de la entrega. La aplicación de registro normal utiliza `registrar-participante-v2` para RADEV’S y `registrar-participante-chiapas` para Chiapas.

No se comprobó el frontend alojado: no se identificó una URL de entrega verificada ni se publicó una nueva compilación. El workflow modificado por el usuario permanece sin tocar. No se puede afirmar que el frontend en servicio tenga la misma versión del repositorio.

## Entrega propuesta para aprobación posterior

1. Resolver la cuenta sin asignación y la provisión ficticia Chiapas con el titular; obtener acceso administrativo seguro. No transmitir claves por chat.
2. Elegir la ruta SQL por etapas o la consolidada. Si se eligen etapas, preparar las migraciones CLI definitivas y evitar que ambas rutas se apliquen. Revisar especialmente el alcance compartido y RADEV’S.
3. Respaldar de forma duradera las versiones publicadas y la configuración vigente. Las copias de código descargadas durante la auditoría están en almacenamiento temporal; sus hashes documentados no reemplazan un respaldo operativo. Refrescar catálogo y versiones inmediatamente antes de publicar.
4. Con aprobación específica, publicar SQL y Edge coordinadamente manteniendo verify_jwt como corresponda y la validación propia de Auth. Los endpoints públicos no deben recibir una configuración de gateway que impida login/registro. Mantener los estados de inscripción actuales.
5. Probar Auth/Storage/Vault reales solo con el inventario ficticio Chiapas aprobado, sin usar cuentas o participantes reales RADEV’S, y verificar limpieza completa. Sin esas pruebas no declarar la integración finalizada.
6. Publicar el frontend aprobado después de validar las dependencias. Aplicar el plan de reversión de `ENTREGA_POR_ETAPAS_CHIAPAS_2026.md` si hay regresión.

## Verificación de esta continuación

Pasaron ESLint, Deno check con lock congelado sobre los 24 endpoints locales y la suite de seguridad: administración Chiapas 17/17, bandejas admin 14/14, bandeja personal 19/19, matriz de aislamiento 224 comprobaciones y perfiles atómicos 10. La matriz incluye rechazo por evento ajeno en el limitador, consulta autorizada por evento en verificar-admin y HMAC separado del contador real. El backend de estas pruebas es simulado; dos solicitudes usan transporte HTTP localhost real. No se repitieron build, SQL o E2E porque esta continuación solo modifica dos endpoints Edge, su matriz de pruebas y documentación; esos checks permanecen aprobados en la entrega anterior. No hubo cambios persistentes en producción, despliegue, push, merge ni apertura de inscripciones.

## Actualización posterior autorizada

El usuario decidió dejar sin cambios el perfil sin asignación: no se elimina ni recibe permisos, y seguirá sin acceso con los guards. Se resuelve así ese punto de revisión, sin modificar la base. Se completaron siete sondas HTTP reales y un ensayo de Vault real con ROLLBACK; su alcance, evidencias y límites están en `VALIDACION_SERVICIOS_REALES_CHIAPAS_2026.md`. La provisión administrativa y los flujos integrales siguen pendientes.
