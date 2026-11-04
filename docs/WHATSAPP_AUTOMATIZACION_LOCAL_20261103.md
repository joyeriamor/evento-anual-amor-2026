# Cierre local de automatización WhatsApp — 3 de noviembre de 2026

**Implementación local preparada y probada. Sin push, despliegues, cambios de producción ni mensajes reales.** Rama `feature/chiapas-evento-2026`; continuación del commit `8844484`. La plantilla `amor_invitacion_confirmada_v1`, idioma `es_MX`, permanece en revisión según la instrucción vigente. Ningún indicador de envío real fue activado.

## Auditoría completada

El bloqueo de consulta anterior quedó resuelto. Se inspeccionaron de producción únicamente metadatos, permisos, restricciones, índices, definiciones SQL y fuentes Edge; no se leyeron tokens reales de Vault ni se cambiaron participantes.

Las tablas existentes `whatsapp_envios_invitacion` y `whatsapp_consentimientos_invitacion` tienen RLS habilitado, sin políticas públicas, y deniegan SELECT/INSERT/UPDATE a `anon`, `authenticated` **y también directamente a `service_role`**. Por eso se usan operaciones SQL restringidas; no se concedieron permisos públicos ni se propuso abrir las tablas. La unicidad existente `(invitacion_id,plantilla)`, la unicidad parcial de `meta_message_id`, las claves foráneas y las restricciones de consentimiento se conservaron.

Las funciones reales `validar_pago_admin`, `validar_pago_admin_chiapas`, `autorizar_cortesia_admin`, `autorizar_cortesia_admin_chiapas` y ambos emisores de invitaciones verifican identidad, perfil activo y asignación por evento. Conservan confirmación, pago/cortesía, QR y auditoría transaccionales. **No se sustituyen ni modifican esas funciones.** El preflight de la migración comprueba además hashes de sus cuerpos y del registro v4 para detenerse si cambiaron desde la auditoría.

El preflight completo también se ejecutó contra el catálogo real dentro de `BEGIN READ ONLY` y `ROLLBACK`: `preflight_solo_lectura_ok`, codificación UTF8. No se aplicó DDL ni se modificaron datos.

El consentimiento ya estaba conectado en las Edge publicadas mediante `crear_registro_publico_v4`, con guardado atómico del registro y consentimiento opcional. Las dos copias locales aún usaban v3: se sincronizaron esas diferencias para evitar una regresión al publicar. En Chiapas se eliminó también lógica de EMPLEADO que era imposible después de limitar los asesores a LUIS/VIRIDIANA y que hacía fallar el compilador. La regla de asesores permanece igual. El formulario público y su diseño no cambiaron.

Evidencia: `WHATSAPP_CATALOGO_AUDITADO_20261103.json` y `WHATSAPP_ADVISORS_20261103.json`. El aviso informativo de RLS sin políticas es coherente con tablas privadas accesibles exclusivamente por operaciones internas; no justifica añadir políticas públicas. Referencia oficial: [permisos de funciones](https://supabase.com/docs/guides/database/functions), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Implementación

- La cola sigue siendo **la tabla existente**. Se reutilizan sus estados: `listo`, `enviando`, `aceptado_meta`, `fallido`, `revision`, `cancelado`, `entregado` y `leido`; solo se añade `simulado`. No hay una segunda columna de estado. Una marca de versión impide consumir trabajos históricos ciegamente. Un preparado histórico puede incorporarse únicamente si seguía pendiente de consentimiento, sin intentos, reserva ni mensaje previo, y vuelve a superar la elegibilidad completa.
- Los disparadores de confirmación/invitación llaman al preparador central. Comprueba evento, registro confirmado y real, pago validado o cortesía autorizada, consentimiento explícito vigente, teléfono mexicano válido y QR activo recuperable con SHA256 correcto. Los errores de preparación no abortan la operación original. No se llama a Meta desde la transacción de aprobación.
- La reserva utiliza `FOR UPDATE SKIP LOCKED`, UUID de reserva, máximo tres intentos y caducidad de diez minutos. Un trabajo vencido pasa a revisión, nunca automáticamente a pendiente. Una reserva antigua no puede cerrar el trabajo de otro proceso. Se conserva el orden registro → invitación → cola para no introducir bloqueos inversos frente a las aprobaciones.
- El worker obtiene el contexto desde el backend, sin sesión administrativa ni IDs de administrador suministrados por cliente. El endpoint administrativo usa JWT validado con `getUser`, perfil activo y asignación activa, comprobados otra vez en SQL. Consultas y reintentos están limitados al evento autorizado.
- Se reutiliza el diseño original, logotipo y fondo navideño en un renderer compartido. Nombre, folio, fecha, recepción, sede y QR vigente aparecen en el PNG. Las funciones administrativas de PNG recuperan ahora el token con una operación de **solo lectura**: no llaman a los emisores y no pueden crear/reemitir un QR por una carrera entre consultas.
- El transporte preparado carga bytes en `/{phone-number-id}/media` y usa el `media_id` en el encabezado de imagen de la plantilla; el cuerpo tiene las cinco variables solicitadas. No hay bucket público, URL pública del QR ni credenciales en frontend. No se ejecutó contra Meta.
- El medio privado se registra antes de iniciar el mensaje. Preparaciones canceladas se limpian por su ID. Una tarea de limpieza, deshabilitada por defecto, permite retirar medios de entregas/fallos definitivos después de siete días; medios de fallos previos al envío pueden retirarse antes. **Aceptados sin entrega y resultados inciertos se conservan para revisión; no se borran ni reenvían automáticamente.** La limpieza también queda bloqueada en modo simulación.
- El webhook verifica HMAC SHA256 sobre el cuerpo original y el número configurado. Conserva únicamente identificador de mensaje, estado y fechas en una bandeja interna nueva con RLS y sin acceso directo a clientes. Esta bandeja es un registro de confirmaciones, no otra cola de envíos. Resuelve confirmaciones que llegan antes de persistir la respuesta de Meta. Entrega/lectura no retroceden por notificaciones tardías. `failed` queda como fallo, sin afirmar entrega ni permitir reenvío ciego.
- El panel diferencia pendiente, proceso, aceptación, entrega, fallo, falta de consentimiento y revisión. Reintenta solo fallos seguros anteriores al mensaje, con consentimiento y permisos vigentes. Permanece oculto por defecto. El workflow permite configurar `VITE_WHATSAPP_PANEL_HABILITADO` como variable del repositorio, con valor predeterminado `false`, sin cambiar disparadores ni protecciones de Pages.

Minatitlán: 6 de diciembre de 2026, Salón RADEV'S 1, recepción 1:00 p. m. Chiapas: 19 de diciembre de 2026, Salón BIANCO, recepción por confirmar.

## SQL y archivos

Migración generada mediante **Supabase CLI 3.0.0**: `supabase/migrations/20261104002122_whatsapp_automatizacion.sql`. Incluye, en una transacción, preflight y los componentes `sql/whatsapp/01` a `05`. No se aplicó en producción. Las fuentes de `sql/whatsapp/referencias/` son copias auditadas de funciones ya existentes para pruebas locales: **no son migraciones y no deben aplicarse otra vez en producción**.

Las operaciones nuevas son `whatsapp_contexto_interno`, `whatsapp_encolar_interno`, `whatsapp_al_confirmar_interno`, `whatsapp_reservar_interno`, `whatsapp_autorizar_salida_interno`, `whatsapp_finalizar_interno`, `whatsapp_admin_interno`, `whatsapp_qr_admin_interno`, `whatsapp_preparar_admin_interno`, `whatsapp_confirmar_entrega_interno`, `whatsapp_conciliar_entrega_interno` y las cuatro operaciones privadas de gestión/limpieza de medios. Todas tienen search_path vacío y permisos explícitos. Solo se concede a service_role lo necesario; los helpers de disparadores/conciliación no se exponen al cliente.

El manifiesto enumera los archivos y hashes del paquete. Incluye SQL, Edge y módulos compartidos, panel, prueba HTTP/SQL/navegador/PNG, lockfile Edge, herramientas de PostgreSQL aisladas y configuración del flag en el workflow. El resto de archivos y respaldos del usuario se conservó. `package.json` y `package-lock.json` de la aplicación no se modificaron.

## Pruebas ejecutadas

| Prueba | Resultado y alcance |
|---|---|
| Motor y transporte | **22/22**, servicios simulados; incluye gates de activación, revocación, token cambiado, fallo/incertidumbre, carga privada, limpieza y webhook |
| Registro público HTTP | **48 comprobaciones**: HTTP localhost real; Supabase, Storage y CAPTCHA simulados; ambos eventos, pago/cortesía, autorización ausente/false/true y evento cliente manipulado |
| Worker HTTP | **24 comprobaciones**: HTTP localhost real, backend y Meta simulados; secreto, rechazo de sesión admin como credencial del worker, origen, simulación y limpieza |
| SQL PGlite | **97 comprobaciones** sobre esquema/datos ficticios, con restricciones auditadas y funciones reales copiadas; incluye registro v4, aprobación de pago/cortesía y cola |
| PostgreSQL 17.11 nativo | **104 comprobaciones**, incluidas las anteriores y concurrencia con conexiones distintas: unicidad, SKIP LOCKED, reserva vencida y orden de bloqueos |
| Migración y rollback | El archivo generado completo se ejecutó en las bases locales; rollback retira disparadores/RPC nuevos y conserva datos/historial |
| Deno | Ocho Edge y prueba de imagen verificadas con `whatsapp-edge.lock` congelado |
| PNG real | **1/1**: render 1122×1402, QR decodificado exactamente igual al token ficticio; recursos originales |
| Seguridad existente ampliada | **17/17, 14/14, 19/19, 252 comprobaciones de aislamiento y 10 de perfiles**; servicios simulados, parte con HTTP localhost real |
| Navegador | **37 comprobaciones de panel y 27 de regresión**, navegador real con Supabase simulado; hay solapamiento entre esas cifras |
| Lint y compilación | Aprobados. Permanece la advertencia previa de tamaño de bundle; no impide el build |

Los fixtures de Vault y las identidades SQL de los ensayos son simulados. PostgreSQL nativo es real, pero **no es un entorno Supabase completo con Auth y cifrado Vault reales**. Tampoco se probó entrega real por Meta. No se presentan esas simulaciones como pruebas reales de dichos servicios. Los servidores PostgreSQL temporales se detuvieron al terminar.

## Repetición local

Desde `C:\PROYECTOS\FIESTAANUAL26`, con Node 24 y dependencias de desarrollo disponibles:

```powershell
node --test tests/whatsapp/motor.test.mjs
node tests/whatsapp/registro-http.test.cjs
node tests/whatsapp/worker-http.test.cjs
$env:FIESTA_WHATSAPP_MIGRACION = 'supabase/migrations/20261104002122_whatsapp_automatizacion.sql'
node tests/whatsapp/sql.integration.mjs
npm ci --prefix tests/whatsapp/herramientas-postgres --ignore-scripts
$env:EMBEDDED_POSTGRES_MODULE = ([Uri](Join-Path $PWD 'tests/whatsapp/herramientas-postgres/node_modules/embedded-postgres/dist/index.js')).AbsoluteUri
$env:PG_MODULE = ([Uri](Join-Path $PWD 'tests/whatsapp/herramientas-postgres/node_modules/pg/lib/index.js')).AbsoluteUri
node tests/whatsapp/postgres-nativo.mjs
npm run test:security
npm run lint
npm run build
npm run test:e2e
node tests/whatsapp/ejecutar-panel.cjs
```

PGlite/Playwright pueden cargarse desde prefijos temporales con `PGLITE_MODULE` y `PLAYWRIGHT_MODULE`; Chrome/Edge local con `FIESTA_CHROME_PATH`. Las herramientas de PostgreSQL tienen dependencias y lockfile separados de la aplicación. El servidor de prueba se crea con UTF-8, puerto efímero y escucha solo en 127.0.0.1, sin crear usuarios del sistema ni instalar servicios. El runner rechaza una URL de base remota. No usarlo contra otra base local con datos propios.

Deno se comprobó en una copia temporal de fuentes + lockfile para no resolver el package.json del frontend; se usan `--no-config --node-modules-dir=none --lock=supabase/whatsapp-edge.lock --frozen=true`. Para la prueba PNG, el único permiso de red de ejecución es `--allow-net=joyeriamor.github.io`. No se modificó el `deno.lock` del usuario.

## Publicación futura — NO ejecutada

1. Revisar este paquete y obtener autorización explícita de push/despliegue. Respaldar esquema y fuentes Edge actuales; repetir preflight si hubo cambios. Las reglas de main y github-pages no se modificaron.
2. Ejecutar primero un ensayo completo en Supabase local/desarrollo autorizado con Auth y Vault reales. No crear una rama de pago ni usar registros reales como fixtures. Mantener la plantilla en revisión y Meta deshabilitado.
3. Aplicar **solo** `20261104002122_whatsapp_automatizacion.sql` como una migración nueva por el canal aprobado. No hacer `db push` sobre las migraciones históricas consolidadas de este repositorio ni aplicar la carpeta referencias. No reescribir pagos, registros o QR existentes.
4. Configurar secretos exclusivamente en el servidor: `WHATSAPP_WORKER_SECRET` aleatorio de al menos 32 caracteres, `META_WHATSAPP_TOKEN`, `META_WHATSAPP_PHONE_NUMBER_ID`, `META_GRAPH_VERSION` soportada, `META_APP_SECRET` y `META_WEBHOOK_VERIFY_TOKEN`. Nunca pegar valores en frontend, Git o reportes. Modo `simulacion`; indicadores de envío/webhook/limpieza en false. No activar cron.
5. Con la CLI **3.0.0**, después de aplicar SQL y configurar secretos, los comandos de publicación preparados son:

```powershell
supabase functions deploy whatsapp-preparar-invitacion whatsapp-generar-qr-png whatsapp-generar-invitacion-png whatsapp-administrar --remote=rkjlqxxmxbiciuhtpnpf --use-api
supabase functions deploy whatsapp-procesar-cola whatsapp-webhook --remote=rkjlqxxmxbiciuhtpnpf --use-api --no-verify-jwt
```

El segundo comando requiere conservar el secreto del worker y la validación HMAC del webhook; no son APIs administrativas públicas. La copia Minatitlán del registro solo sincroniza lo ya desplegado y no necesita redeploy. La limpieza de tipos de Chiapas puede publicarse separadamente, conservando sus secretos actuales y su protección pública CAPTCHA:

```powershell
supabase functions deploy registrar-participante-chiapas --remote=rkjlqxxmxbiciuhtpnpf --use-api --no-verify-jwt
```

No omitir nombres de funciones ni usar `--prune`, para no publicar/borrar funciones ajenas al paquete.

6. Validar las APIs y, solo después, publicar frontend con la variable del repositorio `VITE_WHATSAPP_PANEL_HABILITADO=true`. Mostrar el panel no activa mensajes. Conservar los permisos del entorno github-pages; cualquier excepción temporal de rama debe autorizarse y retirarse al terminar.
7. Para enviar realmente deben confirmarse **las cinco condiciones**: plantilla aprobada, número oficial configurado, credenciales permanentes, prueba manual autorizada y autorización explícita de producción. Los indicadores independientes son `WHATSAPP_ENVIOS_HABILITADOS`, `WHATSAPP_PLANTILLA_APROBADA`, `WHATSAPP_NUMERO_CONFIGURADO`, `WHATSAPP_CREDENCIAL_PERMANENTE`, `WHATSAPP_PRUEBA_MANUAL_AUTORIZADA`, `WHATSAPP_PRODUCCION_AUTORIZADA` y `WHATSAPP_MODO=real`. Webhook/limpieza tienen flags separados. No se cambió el teléfono Business.
8. Conciliación: si hubo solicitud de mensaje pero se perdió la respuesta, el trabajo queda en revisión. No reencolar ni borrar su medio automáticamente. Conservar evidencia de Meta y resolver manualmente. La bandeja de confirmaciones sí resuelve el caso en que el webhook se adelantó a una respuesta que luego pudo persistirse.
9. Rollback operativo: deshabilitar envíos y detener invocaciones; ocultar panel, restaurar las Edge previas que dependan de RPC nuevas y ejecutar `sql/whatsapp/rollback.sql`. Conserva columnas/estados de simulación, medios e historial de confirmaciones; no elimina inscripciones ni QR. Una restauración estructural destructiva exigiría revisión aparte.

No hay atomicidad distribuida entre PostgreSQL y Meta: se revalida consentimiento/QR justo antes del envío, pero existe una ventana entre COMMIT y la red. El diseño evita reintentos ciegos y no promete entrega exactamente una vez. Los pendientes externos son el ensayo Supabase completo, la publicación autorizada y la aprobación/configuración/prueba real de Meta; no se sustituyen por las pruebas locales descritas.
