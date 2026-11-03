# Automatización de invitaciones: preparación local

**No publicar todavía. No se envió WhatsApp, no se desplegó, no se hizo push ni se modificaron datos de producción.**
La plantilla `amor_invitacion_confirmada_v1` (`es_MX`) sigue en revisión según las instrucciones del propietario.

## Auditoría y alcance

Base local inspeccionada: `feature/chiapas-evento-2026`, HEAD `5d6ac8b`. Se conservan los filtros y consentimiento opcional existentes, archivos `.bak` y archivos ajenos sin seguimiento.
Se leyeron de producción únicamente las columnas de las dos tablas existentes y los fuentes de las tres Edge de WhatsApp. No existían copias de esas Edge en Git; se incorporan para revisión local. La consulta de restricciones, RLS, ACL, índices y funciones SQL reales fue bloqueada por la revisión automática por límite de uso. **Auditoría incompleta: ejecutar y revisar `sql/whatsapp/auditoria_solo_lectura.sql` mediante el canal autorizado antes de aprobar cualquier publicación. No usar otro canal para eludir el bloqueo.**

Los fuentes locales muestran que `validar_pago_admin` / `validar_pago_admin_chiapas` confirman la inscripción y recuperan o emiten su invitación en una transacción. `autorizar_cortesia_admin` / `autorizar_cortesia_admin_chiapas` autorizan la cortesía y emiten la invitación. Las Edge `validar-pago[-chiapas]` y `administrar-invitacion[-chiapas]` mantienen sus contratos. No se cambian esos archivos.

## Archivos y comportamiento preparado

- `sql/whatsapp/01_automatizacion_propuesta.sql`: amplía la tabla existente con fase de automatización independiente; evita suponer los valores permitidos por la restricción antigua `estado`. Filas históricas quedan fuera del procesador. Usa la unicidad existente `(invitacion_id,plantilla)`. Agrega recuperación de token **solo lectura**, cotejo SHA256 con Vault, encolado, reserva `SKIP LOCKED`, autorización de salida y finalización con UUID de reserva.
- Los disparadores de invitaciones y confirmaciones intentan preparar la cola. Sus errores no abortan pagos/cortesías. No efectúan llamadas HTTP. No reconstruyen tokens ni llaman a RPC emisoras. No hay backfill masivo.
- Elegibilidad: evento reconocido, registro confirmado, `es_prueba=false`, pago validado o cortesía autorizada, consentimiento explícito no retirado, teléfono mexicano válido, QR activo/emitido y hash correcto. Ausencia de consentimiento nunca autoriza el envío. Teléfonos existentes de diez dígitos se convierten a `52` + diez dígitos; otros países no están habilitados.
- `02_administracion_propuesta.sql` y `whatsapp-administrar`: lista paginada y reintento manual de fallos seguros, con administrador activo y asignación activa por evento. El usuario se obtiene de `getUser`, el evento del encabezado interno reemplazado por `serveEvento`; se verifica de nuevo en SQL. No retorna teléfonos, token QR ni credenciales.
- `whatsapp-procesar-cola`: un trabajo por invocación, secreto de backend independiente de sesiones administrativas. Simulación por defecto. No existe programador configurado.
- `_shared/whatsapp-imagen.ts`: conserva el SVG del generador original, fondo navideño y logotipo originales del proyecto. Admin y procesador comparten el diseño. El QR codifica el token recuperado; la imagen se conserva solo en memoria y se envía como bytes privados. No se publica en Storage.
- `_shared/whatsapp-meta.ts`: carga multipart en `/{phone-number-id}/media`, obtiene `media_id` y lo referencia en el encabezado de imagen de `/{phone-number-id}/messages`, con cinco variables. HTTP solo en modo real autorizado. No se registran cuerpos de error, teléfonos ni secretos.
- `03_webhook_propuesta.sql`, `whatsapp-webhook`: confirmación `delivered/read` con HMAC SHA256 del cuerpo original, número configurado y `wamid` coincidente. Estados monotónicos. Webhook deshabilitado por defecto. “Aceptado” no implica “Entregado”.
- `WhatsAppAdmin.tsx` / `PanelAdmin.tsx`: consulta y reintento administrativo, detrás de `VITE_WHATSAPP_PANEL_HABILITADO=true`. Se mantiene oculto por defecto hasta desplegar y validar backend; formulario público sin cambios.
- `rollback.sql`: retira únicamente operaciones/disparadores nuevos. Conserva columnas e historial para conciliación; no elimina tablas, inscripciones ni QR.

## Seguridad, reintentos y límites

Las nuevas RPC se revocan de PUBLIC, anon y authenticated; solo service_role puede ejecutarlas. Los permisos/RLS antiguos aún requieren auditoría real. No se amplían permisos de las tablas para resolver acceso interno. El servicio nunca acepta un administrador indicado por el navegador.
Reserva con UUID y máximo tres intentos. No reencola automáticamente trabajos caducados: pasan a `incierto`. Cualquier error después de iniciar la petición de mensaje queda incierto, incluso un rechazo explícito: decisión conservadora contra duplicados. El reintento manual exige fallo anterior al envío, sin `wamid` ni marca de salida, y elegibilidad vigente. Simulaciones terminan en `simulado` y no se convierten automáticamente en envíos reales.

La validación final vuelve a leer consentimiento, pago/cortesía, registro y QR después de generar/cargar imagen. Existe una ventana inevitable entre la transacción de autorización y la solicitud externa; no se garantiza atomicidad entre PostgreSQL y Meta. Las reservas caducan a diez minutos y el transporte usa timeout de veinte segundos. Una pérdida de respuesta o de persistencia posterior a Meta requiere conciliación humana, nunca reenvío ciego.

Los medios de solicitudes aceptadas/inciertas no se eliminan inmediatamente, porque Meta puede necesitarlos para entregar. **Falta aprobar e implementar la política de retención/conciliación de esos medios antes de producción.** Medios de preparaciones canceladas se eliminan por su ID. No hay bucket público ni URL permanente.
La carrera de un webhook recibido antes de persistir `wamid` necesita conciliación adicional antes de uso real; no se afirma entrega si no puede asociarse.

## Secretos y activación futura (NO ejecutar ahora)

Solo secretos del servidor: `WHATSAPP_WORKER_SECRET` (aleatorio, mínimo 32 caracteres), `META_WHATSAPP_TOKEN`, `META_WHATSAPP_PHONE_NUMBER_ID`, `META_GRAPH_VERSION` (versión soportada confirmada al publicar), `META_APP_SECRET`, `META_WEBHOOK_VERIFY_TOKEN`.
No incorporar sus valores a Git, frontend, reportes ni argumentos visibles de comandos. Usar el gestor de secretos autorizado.

Por defecto: `WHATSAPP_MODO=simulacion`; todos los indicadores siguientes ausentes o `false`:
`WHATSAPP_ENVIOS_HABILITADOS`, `WHATSAPP_PLANTILLA_APROBADA`, `WHATSAPP_NUMERO_CONFIGURADO`, `WHATSAPP_CREDENCIAL_PERMANENTE`, `WHATSAPP_PRUEBA_MANUAL_AUTORIZADA`, `WHATSAPP_PRODUCCION_AUTORIZADA`, `WHATSAPP_WEBHOOK_HABILITADO`.

## Publicación por etapas — instrucciones, no ejecución

1. Completar auditoría de solo lectura y contrastar definiciones/ACL/RLS/restricciones con las propuestas. Obtener respaldo de catálogo y Edge actuales; revisar diferencias desde `5d6ac8b`. Corregir cualquier incompatibilidad y repetir pruebas.
2. En entorno desechable LOCAL con Supabase/Auth/Vault y PostgreSQL real, validar migración, rollback, concurrencia real, permisos cruzados, decodificación del PNG y registro público de ambos eventos. No crear una rama de pago sin autorización.
3. Con CLI instalada y versión verificada, consultar `supabase migration new --help`, ejecutar `supabase migration new whatsapp_automatizacion` y colocar las tres propuestas SQL en el archivo generado, quitando los límites BEGIN/COMMIT duplicados. No aplicar a ciegas las migraciones históricas consolidadas de este repositorio ni ejecutar `db push` sobre ellas.
4. Solicitar autorización de publicación para este paquete concreto. Sin ella no hacer push ni aplicar SQL ni desplegar Edge. Revisar y aplicar la migración nueva por el canal aprobado; no modificar registros existentes para probar.
5. Consultar `supabase functions deploy --help`. Desplegar solamente `whatsapp-preparar-invitacion`, `whatsapp-generar-qr-png`, `whatsapp-generar-invitacion-png`, `whatsapp-administrar`, `whatsapp-procesar-cola`, `whatsapp-webhook` con el directorio compartido incluido. Mantener verificación JWT en las cuatro funciones administrativas. Worker y webhook requieren `--no-verify-jwt` y sus validaciones propias; no publicar esos endpoints antes de configurar y validar sus secretos. No desplegar otras Edge ni cambiar el teléfono Business.
6. Configurar secretos mediante el gestor autorizado con todos los indicadores de envío real en falso. No activar cron. Probar worker simulado con fixture identificado en entorno local; no consumir cola real de producción como ensayo.
7. Publicar frontend solo después de validar `whatsapp-administrar`, habilitando únicamente su panel con `VITE_WHATSAPP_PANEL_HABILITADO=true`. No abrir/cerrar inscripciones ni cambiar formularios.
8. Para envío real: plantilla aprobada, número oficial configurado, credenciales permanentes verificadas, prueba manual expresamente autorizada, conciliación/retención resueltas y autorización explícita de producción. Cambiar indicadores solo tras esa autorización, nunca por aprobar este desarrollo local.
9. Rollback: detener invocaciones y marcar envío real falso primero, conservar bitácora y medios para conciliar; retirar panel; ejecutar `rollback.sql` y restaurar las tres Edge originales desde respaldo. No borrar trabajos inciertos ni QR vigentes.

Referencias oficiales revisadas: [plantillas Meta](https://whatsapp.github.io/WhatsApp-Nodejs-SDK/api-reference/messages/template/) (SDK archivado; confirmar contrato vigente al publicar), [medios WhatsApp](https://developers.facebook.com/documentation/business-messaging/whatsapp/business-phone-numbers/media) (consulta recibió HTTP 429 en esta sesión). Validar versión Graph y documentación actual antes de activar modo real.

## Resultados ejecutados el 3 de noviembre de 2026

- `node --test tests/whatsapp/motor.test.mjs`: **18/18**; servicios simulados, transporte HTTP de Meta reemplazado por un adaptador ficticio. La concurrencia aquí demuestra exclusión del adaptador simulado; no certifica sesiones PostgreSQL simultáneas.
- `node tests/whatsapp/sql.integration.mjs`: **27 comprobaciones** PGlite 0.5.11; SQL ejecutado de verdad sobre catálogo y datos ficticios, Vault representado por una tabla local. Incluye pago/cortesía, exclusiones, unicidad, token/hash, reserva, reintento seguro, incertidumbre, permisos cruzados e inactivos, webhook monotónico, aislamiento de fallo de cola y rollback. No es una prueba del servicio Vault/Auth real ni de la configuración RLS de producción.
- `npm run lint`: aprobado después de corregir la expresión de control del renderer original.
- `npm run build`: aprobado; tsc y Vite. Advertencia existente de tamaño de bundle superior a 500 kB, no impide compilación.
- `npm run test:e2e`: **27 comprobaciones** existentes, navegador real en localhost, Supabase HTTP simulado. Comprueba rutas, formulario visible y operación administrativa existente de ambos eventos; no crea participantes reales ni certifica un alta pública completa contra Supabase.
- `node tests/whatsapp/ejecutar-panel.cjs`: **37 comprobaciones**, navegador real, HTTP simulado; panel habilitado solo en ese servidor de prueba, ambos eventos, estado aceptado diferenciado de entregado, sin consentimiento y reintento con evento correcto. Parte de esas comprobaciones repite la regresión anterior; no sumar ambas cifras como casos independientes.
- Deno 2.9.8 `check` de las **seis Edge**: aprobado en copia temporal aislada, sin modificar `deno.lock` del usuario. Dependencias directas fijadas en sus imports; integrar el cierre de dependencias nuevo en la estrategia de lockfile Edge antes de publicación.
- `deno test --no-config --no-lock --node-modules-dir=none --allow-net=joyeriamor.github.io tests/whatsapp/imagen.test.ts`: **1/1**. Renderiza PNG real de 1122×1402 con recursos originales, decodifica el QR y coteja exactamente el token **ficticio**. No consulta Vault real ni emplea una invitación real. Se corrigió la interoperabilidad de tipos CommonJS del decodificador de prueba; no se omitió la revisión de tipos.

Los comandos se ejecutaron en `C:\PROYECTOS\FIESTAANUAL26`, salvo Deno, que utilizó una copia temporal de los mismos fuentes para evitar resolver dependencias ajenas del frontend. PGlite se instaló en un prefijo temporal porque faltaba en `node_modules`; no se cambiaron `package.json` ni `package-lock.json`.

Pendientes que impiden declarar listo para producción: catálogo/ACL/RLS reales, PostgreSQL concurrente y Supabase local completo, activación/transmisión real expresamente autorizada y confirmación de Meta, retención y conciliación de medios/webhooks tempranos, lockfile Edge y versión Graph actual. No se sustituyen estas pruebas por las simulaciones descritas.

Regresión de seguridad final: `npm run test:security` aprobó **17/17**, **14/14**, **19/19**, **237 comprobaciones de aislamiento** (incluye transporte HTTP localhost real con backend simulado) y **10 comprobaciones de perfiles/Auth simulado**. La primera ejecución detectó una fixture antigua que devolvía `ASESOR FICTICIO`, incompatible con la restricción de LUIS/VIRIDIANA ya presente en HEAD. Se corrigió únicamente `tests/chiapas/aislamiento-eventos.test.cjs`: fixture positiva permitida y caso negativo adicional para asesor no permitido. No se cambió la regla de asesores ni los endpoints de inscripción.

Archivos existentes modificados: `src/pages/PanelAdmin.tsx` y `tests/chiapas/aislamiento-eventos.test.cjs`. El resto de archivos del paquete son nuevos en Git, incluidas las tres Edge que antes solo estaban publicadas. El manifiesto enumera los archivos y sus hashes. La regla `.gitignore` existente ignora `supabase/`; se deben incorporar **solo las rutas exactas del paquete**, nunca forzar la carpeta completa porque podría contener secretos o archivos del usuario.

Para repetir las pruebas, usar las dependencias ya declaradas en el proyecto o los módulos temporales mediante `PGLITE_MODULE` y `PLAYWRIGHT_MODULE`, y Chrome/Edge local mediante `FIESTA_CHROME_PATH`. No instalar ni sustituir dependencias globales. Las copias temporales y respaldos no son artefactos de publicación.
