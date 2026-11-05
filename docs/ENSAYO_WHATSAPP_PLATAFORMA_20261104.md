# Ensayo integral aislado de WhatsApp — preparado el 4 noviembre 2026

## Estado
Desarrollo local y verificaciones completos. No se aplicó esta migración en producción, no se publicó la Edge nueva, no se activó el flag del ensayo y no se envió una invitación desde este paquete.
La prueba previa «Hello World» fue un envío desde el panel de Meta y NO valida este recorrido de plataforma.

## Recorrido preparado
Una entrada administrativa local permite iniciar sesión con Auth real y, tras confirmar el ensayo, crear una inscripción ficticia de Chiapas, autorizar su cortesía, emitir un QR cifrado en Vault, procesar la plantilla con imagen y consultar la entrega.
La creación y la aprobación llaman a las funciones publicadas crear_registro_prueba_admin_chiapas y autorizar_cortesia_admin_chiapas. El motor, renderer PNG y transporte a Meta son los mismos del flujo preparado. El webhook y la conciliación existentes registrarán entrega/lectura por el identificador de mensaje.
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

## Archivos y despliegue propuesto
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

## Ejecución real pendiente de autorización explícita
La restricción inicial del usuario requiere autorización antes de modificar esquema o funciones de producción. El alcance propuesto es aplicar solo esta migración, publicar solo esta Edge, habilitar solo su flag y ejecutar el ensayo identificado hacia el destinatario autorizado con el emisor de pruebas de Meta.
Después se cerrará el ensayo y se revocará solo su QR. La limpieza definitiva se limitará a los IDs derivados de esta fila de control, su imagen sintética en fotos-promotoras y su medio de Meta; primero se deshabilitará el flag/retirará el RPC para impedir otra alta. No se eliminarán carpetas ni datos de terceros. Conservar evidencia de estado antes de limpiar y no borrar medios de una entrega incierta.
El archivo sintético previsto es 3dc92160-79af-4bf7-b770-263038e88900/pruebas/2bba9e9e-8751-49df-b1bb-17a82c7120d3.png; los IDs de registro, invitación y Vault serán los generados por el backend y se verificarán antes de cualquier limpieza.
Para finalizar la prueba se requiere una sesión administrativa real introducida por el usuario en la entrada local, autorización vigente, credenciales de Meta válidas y la confirmación de recepción de la invitación. Nada de esto se sustituye por los ensayos simulados anteriores.
