# Ensayo integral aislado de WhatsApp — ejecutado y retirado el 5 noviembre 2026

## Estado final verificado
Ensayo REAL completado: sesión administrativa Hugo validada por Auth, fotografía sintética en Storage, inscripción ficticia de Chiapas, cortesía, QR cifrado en Vault, imagen privada y envío de la plantilla aprobada desde la plataforma. Meta aceptó el único mensaje a las 14:20:15 UTC del 5 noviembre 2026 (08:20:15 México). El titular confirmó en este chat que recibió la invitación con imagen y QR. No fue el Hello World del panel de Meta.
La recepción está confirmada por el destinatario; NO se verificó el retorno automático de entrega/lectura: entregado_at y leido_at permanecían NULL. No afirmar que el webhook de entrega quedó validado integralmente.
Ensayo cerrado a las 14:21:24 UTC; registro cancelado y QR revocado antes de limpiar. Interruptor WHATSAPP_ENSAYO_PLATAFORMA_HABILITADO=false guardado y rechazo real 503 ensayo_deshabilitado verificado. Cola general apagada, modo simulacion, producción no autorizada; número oficial sin conectar ni migrar.
Limpieza definitiva autorizada por el titular y completada: 0 filas del registro, invitación, cola, consentimiento, promotora, control y secreto de Vault; foto ausente en Storage. Medio privado de Meta eliminado con respuesta success=true. Solo se borraron estos datos ficticios y sus dos auditorías identificadas.

## Recorrido ejecutado
Una entrada administrativa local permite iniciar sesión con Auth real y, tras confirmar el ensayo, crear una inscripción ficticia de Chiapas, autorizar su cortesía, emitir un QR cifrado en Vault, procesar la plantilla con imagen y consultar la entrega.
La creación y la aprobación llaman a las funciones publicadas crear_registro_prueba_admin_chiapas y autorizar_cortesia_admin_chiapas. El motor, renderer PNG y transporte a Meta son los mismos del flujo preparado. El webhook y la conciliación existentes están preparados para registrar entrega/lectura por el identificador de mensaje; ese retorno no se observó en esta ejecución.
El formulario público y el panel administrativo publicado no se modificaron; no se agregó un botón de pruebas al sitio.

## Aislamiento
- Ensayo fijo: 2bba9e9e-8751-49df-b1bb-17a82c7120d3. Una fila de control y un solo intento de envío. No hay reintento automático.
- Evento fijo: Chiapas 3dc92160-79af-4bf7-b770-263038e88900. No se registran ni modifican datos de RADEV'S.
- Emisor fijo: Phone Number ID 1302305149644004, perteneciente al número de pruebas de Meta. No se conecta ni migra el número oficial del dispositivo.
- Destinatario obtenido del secreto existente WHATSAPP_TEST_DESTINATARIO y permitido únicamente si coincide con la huella del número autorizado por el usuario, terminado en 0814. El cliente no puede escoger otro número.
- JWT verificado con Auth, administrador activo y asignación activa a Chiapas; SQL vuelve a comprobar permisos y propiedad del ensayo. No se aceptan IDs de administrador, registro, invitación o evento del cliente.
- Tabla de control con RLS y sin permisos directos para anon/authenticated/service_role. RPC interno concedido solo al backend.
- La inscripción permanece es_prueba=true y no ocupa cupo real. La protección operativa que rechaza pruebas NO se cambia.
- El envío de ensayo conserva automatizacion_version=NULL, por lo que el selector operativo automatizacion_version=1 no puede reservarlo.
- La nueva Edge exige WHATSAPP_ENSAYO_PLATAFORMA_HABILITADO=true y rechaza operar si la cola general está habilitada o WHATSAPP_MODO=real. Los interruptores generales permanecen apagados.
- Antes de reservar se comprueban, por API de Meta, el acceso al emisor y la plantilla aprobada amor_invitacion_confirmada_v1 en es_MX con encabezado IMAGE y cinco variables. Una falla previa no consume el intento ni envía mensajes.
- QR y credenciales no aparecen en la respuesta de estado ni en logs. La imagen privada usa media_id, sin URL pública.
- Entrada local con sesión en memoria, sin persistencia de contraseña ni tokens. El paquete del cliente se revisó: sin JWT service_role ni claves sb_secret.

## Archivos y despliegue realizado
- Migración local generada por Supabase CLI 3.0.0: supabase/migrations/20261105015503_whatsapp_ensayo_plataforma.sql (fecha UTC).
- Una tabla nueva: whatsapp_ensayo_plataforma. Un RPC nuevo: whatsapp_ensayo_control_interno. No se reemplaza SQL operativo.
- Una Edge nueva: whatsapp-ensayo-plataforma, usando módulos compartidos existentes y lockfile congelado supabase/whatsapp-edge.lock.
- Un flag nuevo, apagado si falta: WHATSAPP_ENSAYO_PLATAFORMA_HABILITADO.
- Helper local: tests/whatsapp/ensayo-plataforma.html. La compilación normal no lo publica en dist.
- Rollback: sql/whatsapp/ensayo-plataforma-rollback.sql. Deshabilitar primero el flag y retirar/desactivar la Edge; el rollback retira solo el RPC nuevo y conserva el historial para conciliarlo.
No ejecutar db push sobre las migraciones consolidadas ni aplicar las referencias SQL de tests contra producción.

## Validación local ejecutada
- 154 comprobaciones de PostgreSQL nativo (incluyen la base previa de 104 y 50 nuevas de ensayo). Catálogo, identidades y Vault ficticios; hay concurrencia real en la suite base. No equivale a Supabase completo.
- 12/12 pruebas Deno del controlador: sesión, permiso antes de Storage, flags, origen, inyección de campos, número autorizado, preflight y único envío con proveedor simulado.
- 20 comprobaciones HTTP: Deno/HTTP localhost reales; Auth, Storage y RPC simulados. Sin red externa.
- 16 comprobaciones de navegador: interfaz local real con Auth/Edge simulados; consentimiento, etapas y bloqueo de doble envío.
- Regresión existente: 17/17, 14/14, 19/19, 252 de aislamiento y 10 de perfiles, con backend simulado.
- Deno check con dependencias congeladas, lint y build aprobados. Persiste la advertencia previa de tamaño de bundle.
- Se comprobaron las copias de funciones publicadas y se corrigieron las referencias/separadores del catálogo ficticio antes de repetir SQL.

## Evidencia de ejecución y retiro
Paquete de envío en GitHub: 791fc8fe678adadf6f6eb5d144cc908280090203.
Migración inicial remota: 20261105021541 whatsapp_ensayo_plataforma_aislado; corresponde a la migración local 20261105015503_whatsapp_ensayo_plataforma.sql. No aplicar ambas otra vez.
Edge de envío: whatsapp-ensayo-plataforma, SHA 6094172b751a688dab297ff9a065019accb785fc76021d1b0d186794bed35811 (el catálogo final indicaba versión 4).
El token anterior falló en la consulta previa, con 0 intentos. El usuario renovó META_WHATSAPP_TOKEN directamente en Supabase; no se extrajo ni guardó en código. La consulta previa del token nuevo y de la plantilla aprobada pasó; se reservó y ejecutó exactamente 1 intento.

IDs ficticios verificados antes de borrar:
- Control: 2bba9e9e-8751-49df-b1bb-17a82c7120d3.
- Registro: f36d6fea-d9d2-4b3d-9dd4-b07352dbe10d; folio EA26-80F23802A7D24BB9A9CEBAA4B0A75040.
- Invitación: c8d5d792-9924-4675-9c2c-d55af5b3c5f4.
- Cola: db605cbb-7700-47b3-a326-40b083610e62; intentos=1; aceptado_meta; sin error.
- Promotora: 2244de69-8566-42b2-a82d-dd5721955eee.
- Vault: 23b2c7e6-db92-4ab8-a2b7-016f83872af0 (nunca se extrajo su secreto).
- Medio privado Meta: 4530699950493174.
- Foto: fotos-promotoras/3dc92160-79af-4bf7-b770-263038e88900/pruebas/2bba9e9e-8751-49df-b1bb-17a82c7120d3.png.
- Auditorías 66 y 67, limitadas a ese registro e invitación. Sin pagos ni accesos asociados.

### Limpieza y límite observado
Se preparó un auxiliar de limpieza con 9 pruebas Deno simuladas y verificación de tipos congelada. Solo admite JWT administrativo, asignación Chiapas, ambos interruptores apagados, origen local, confirmación y fixture exacto cerrado. No admite IDs ni destinatarios del cliente.
Se publicó temporalmente sobre la propia Edge del ensayo (versión 5; SHA 1802a684bb3fcc62669931efad8bf1c26eaf7a030f9288f91c2f240d8710fbf6). Eliminó correctamente el medio de Meta. El siguiente paso de marcado fue rechazado por la función compartida, que solo marca medios de estados cancelado/fallido/pendiente_consentimiento, no aceptado_meta. Se detuvo antes de Storage; NO se debilitó ni cambió esa función operativa. Las 9 pruebas aisladas NO detectaban esta restricción SQL real.
Se registró entonces media_eliminado_at mediante DML limitado a la cola exacta, registro es_prueba=true de Chiapas, control cerrado, reserva y media verificados. La fotografía exacta se eliminó mediante la interfaz oficial de Storage; se comprobó ausencia en la interfaz y en su catálogo, sin borrar metadatos directamente por SQL.
Después se retiró solo el RPC del ensayo con la migración remota 20261105143629 retirar_ensayo_whatsapp_plataforma, correspondiente al archivo local 20261105143527_retirar_ensayo_whatsapp_plataforma.sql (mismo SQL; no reaplicar). La limpieza SQL se realizó en una transacción REPEATABLE READ, comprobando IDs, evento, es_prueba, nombres ficticios, cierre, QR revocado, medio eliminado, foto ausente y ausencia de pagos/accesos/referencias ajenas. Cantidades eliminadas verificadas; comparación MD5 de todos los registros reales antes/después idéntica dentro de la transacción.
Verificación posterior: registro=0, invitación=0, cola=0, consentimiento=0, promotora=0, control=0, Vault=0, foto=0; RPC ausente. Conteos reales observados: Chiapas 34 y RADEV'S 166; crecieron desde la línea base por operación real, nunca se reiniciaron a cero.
El código exacto del auxiliar retirado y sus pruebas se conserva como evidencia .txt en docs/evidencias/ensayo-whatsapp-20261105/, fuera del bundle. No desplegarlo ni reutilizarlo.

### Estado de la Edge retirada
La revisión automática rechazó restaurar la Edge de envío una vez concluida la limpieza: consideró innecesario reemplazar otra función en producción y señaló que el RPC ya no existe. No se reintentó ni se rodeó ese rechazo. La Edge queda en su última versión 5, con flag=false y RPC retirado: no puede crear, confirmar, enviar ni limpiar. La tabla de control queda vacía, con RLS y sin permisos directos. El index.ts del repositorio conserva el controlador de envío original para referencia; el snapshot .txt documenta exactamente la versión 5 ya inoperante.
No se modificaron SQL/Edges operativos de RADEV'S, las casillas de consentimiento, las inscripciones reales ni el frontend público durante este cierre.

## Pendientes antes de activar automatización general
1. Configurar el emisor oficial mediante una opción compatible con conservar WhatsApp Business y su historial, verificar elegibilidad de coexistencia y obtener credencial permanente. No migrar ni borrar la cuenta del dispositivo sin autorización específica.
2. Comprobar suscripción de la cuenta WhatsApp a la aplicación y recepción REAL de estados firmados de entrega/lectura. Este ensayo confirmó recepción por el titular, pero no actualizaciones automáticas del webhook.
3. Revisar con el titular la configuración definitiva y autorizar expresamente la activación de la cola general. Los envíos automáticos siguen apagados.
No repetir esta prueba ni reemitir QR del ensayo eliminado.

## Comprobaciones finales
Lint y build ejecutados nuevamente el 5 noviembre: aprobados; advertencia existente de bundle superior a 500 kB. No hubo publicación del frontend. La migración de retiro se verificó contra producción: RPC ausente. Las pruebas locales enumeradas arriba conservan su alcance simulado; solo el recorrido narrado como real usó Supabase y Meta reales.
