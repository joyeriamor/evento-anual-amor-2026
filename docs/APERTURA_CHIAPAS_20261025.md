# Apertura autorizada de Chiapas · 25 de octubre de 2026

El usuario autorizó abrir las inscripciones y confirmó la sede SALÓN BLANCO, Tuxtla Gutiérrez, Chiapas. El horario continúa por confirmar; la medianoche provisional de la base no es el horario del evento.

## Cambios publicados

- Página pública y formulario Chiapas habilitados mediante configuración propia, sin cambiar el interruptor del formulario RADEV’S.
- Sede actualizada en página e invitaciones de administración y personal. Horario por confirmar.
- Se conserva el cierre independiente del servidor: REGISTROS_CHIAPAS_HABILITADOS debe ser true, junto con evento activo, CAPTCHA, validaciones y cupo de 500.
- SQL de apertura acotado al UUID de Chiapas y cierre reversible separado. No modifica esquema ni registros RADEV’S.

## Verificación realizada

Batería local completa aprobada: lint, TypeScript, build, 25 entradas Deno, pruebas HTTP simuladas y locales, aislamiento, SQL PostgreSQL local y E2E. En esta revisión: 15 comprobaciones E2E con backend simulado y 23 del build estático con red externa bloqueada. No se presentan como pruebas remotas.

Ensayo real por navegador publicado, con sesión hugo: registro ficticio marcado es_prueba, fotografía y comprobante privados, aparición en bandeja Chiapas, pago ficticio de $300 validado e invitación generada en Vault. Sin transferencia ni cambios a datos reales.

Seis pruebas SQL remotas con identidad declarada y ROLLBACK: recuperación conserva QR; renovación cambia QR; QR anterior no autorizable; QR Chiapas rechazado en RADEV’S; primera entrada Chiapas correcta; doble entrada bloqueada. Son pruebas de RPC y Vault en PostgreSQL real, no nuevas sesiones HTTP autenticadas ni escaneo físico.

Registro de ensayo: 2d25dbc3-e10f-4dd0-b460-8ae45e9688b2. Folio EA26-0569A274730143CA972E0A68FD6CDC46. Dos archivos sintéticos con la ruta 3dc92160-79af-4bf7-b770-263038e88900/pruebas/a9e71ba2-8fa9-4fc9-b33c-bd4e6674f02b.png, uno en cada bucket privado. Limpiar únicamente este ensayo, incluidos sus recursos dependientes; no borrar actividad general de hugo.

## Publicación y apertura ejecutadas

Publicado el commit 3247403c36f82accf56f161753c436ed80e6645d mediante GitHub Actions #17, ejecución https://github.com/joyeriamor/evento-anual-amor-2026/actions/runs/40170106870, resultado Success en 30 segundos. La excepción temporal de la rama fue retirada; github-pages vuelve a admitir solo main, conservando las demás protecciones.

Tres rutas públicas respondieron HTTP 200; JavaScript y CSS publicados coinciden byte por byte con el candidato compilado. Sede guardada únicamente en el evento Chiapas, estado activo e interruptor REGISTROS_CHIAPAS_HABILITADOS=true. No se cambiaron otras variables del servidor ni se volvieron a desplegar Edge Functions.

21 sondas HTTP reales aprobadas: 20 endpoints privados rechazaron solicitudes sin sesión con 401; el registro público Chiapas superó la barrera de cierre y rechazó JSON con 415, como exige su contrato multipart.

Ensayo administrativo eliminado junto con sus dos archivos privados, pago, invitación, secreto Vault y participante. SQL confirmó cero registros, pagos e invitaciones Chiapas antes de activar el servidor; RADEV’S conservó 28 registros y la misma huella de su evento.

Se completó además un envío público real desde GitHub Pages: Turnstile produjo la validación automáticamente, sin manipular tokens ni desactivar la protección. Una promotora ficticia obtuvo folio EA26-3351CF16A3FD4A0AA390F526B3EF7111 y quedó pendiente de autorización, sin pago ni invitación. Registro d584ec01-b3e9-408c-84be-0ef163304444; fotografía sintética fotos-promotoras/3dc92160-79af-4bf7-b770-263038e88900/a99292df-75a5-41e5-95f4-eedc2f695567.png. Este envío público utiliza es_prueba=false por diseño; se identifica como ensayo por UUID, folio, nombre y teléfono ficticios exactos. No se confunde con un registro real del público.

Cuatro pruebas adicionales de RPC real con ROLLBACK aprobaron: cortesía pendiente sin pago/QR; autorización confirma y exenta; emite invitación respaldada en Vault; no crea pago. La autorización del ensayo público fue revertida: no queda una invitación activa por este paso.

Cierre completado: el último ensayo público y su fotografía fueron eliminados con autorización explícita. La comprobación final independiente confirmó 0 participantes, 0 pagos, 0 invitaciones y 0 accesos de Chiapas, 0 archivos sintéticos, 0 promotoras de ensayo y 0 secretos Vault del ensayo administrativo. Se conservan dos marcadores vacíos de carpeta de 0 bytes en Storage; no son fotografías ni comprobantes. RADEV’S conserva 28 registros y la huella de su evento permanece idéntica. El servidor Chiapas queda activo y abierto. Cualquier inscripción real posterior se conserva. No se han probado cámara o lector físico ni envío real por WhatsApp. El horario sigue por confirmar.

RADEV’S: 28 registros al inicio; huella de la fila del evento d4d8d28273af03c03ba00fcb8f77f716. Conservar y comparar al cierre. Los eventos comparten infraestructura Supabase; el aislamiento de autorización no equivale a infraestructura independiente.

Para cerrar Chiapas: primero REGISTROS_CHIAPAS_HABILITADOS=false y luego, si procede, sql/chiapas/cierre_apertura_20261025.sql. No borrar inscripciones para cerrar. La publicación desde main todavía puede reemplazar la versión de la rama; no hacer merge ni publicar main sin revisión.
