# Apertura autorizada de Chiapas · 25 de octubre de 2026

El usuario autorizó abrir las inscripciones y confirmó la sede SALÓN BLANCO, Tuxtla Gutiérrez, Chiapas. El horario continúa por confirmar; la medianoche provisional de la base no es el horario del evento.

## Cambios preparados

- Página pública y formulario Chiapas habilitados mediante configuración propia, sin cambiar el interruptor del formulario RADEV’S.
- Sede actualizada en página e invitaciones de administración y personal. Horario por confirmar.
- Se conserva el cierre independiente del servidor: REGISTROS_CHIAPAS_HABILITADOS debe ser true, junto con evento activo, CAPTCHA, validaciones y cupo de 500.
- SQL de apertura acotado al UUID de Chiapas y cierre reversible separado. No modifica esquema ni registros RADEV’S.

## Verificación realizada antes de publicar

Batería local completa aprobada: lint, TypeScript, build, 25 entradas Deno, pruebas HTTP simuladas y locales, aislamiento, SQL PostgreSQL local y E2E. En esta revisión: 15 comprobaciones E2E con backend simulado y 23 del build estático con red externa bloqueada. No se presentan como pruebas remotas.

Ensayo real por navegador publicado, con sesión hugo: registro ficticio marcado es_prueba, fotografía y comprobante privados, aparición en bandeja Chiapas, pago ficticio de $300 validado e invitación generada en Vault. Sin transferencia ni cambios a datos reales.

Seis pruebas SQL remotas con identidad declarada y ROLLBACK: recuperación conserva QR; renovación cambia QR; QR anterior no autorizable; QR Chiapas rechazado en RADEV’S; primera entrada Chiapas correcta; doble entrada bloqueada. Son pruebas de RPC y Vault en PostgreSQL real, no nuevas sesiones HTTP autenticadas ni escaneo físico.

Registro de ensayo: 2d25dbc3-e10f-4dd0-b460-8ae45e9688b2. Folio EA26-0569A274730143CA972E0A68FD6CDC46. Dos archivos sintéticos con la ruta 3dc92160-79af-4bf7-b770-263038e88900/pruebas/a9e71ba2-8fa9-4fc9-b33c-bd4e6674f02b.png, uno en cada bucket privado. Limpiar únicamente este ensayo, incluidos sus recursos dependientes; no borrar actividad general de hugo.

## Pendientes de ejecución

Publicar este candidato, aplicar sede/estado Chiapas, activar su interruptor de servidor, comprobar formulario público y limpiar el ensayo identificado. Verificar cero antes de la apertura al público. Cualquier inscripción real posterior se conserva. El envío público positivo con Turnstile requiere comprobación real; el ensayo administrativo no demuestra ese paso. Cámara y lector físico tampoco se han probado.

RADEV’S: 28 registros al inicio; huella de la fila del evento d4d8d28273af03c03ba00fcb8f77f716. Conservar y comparar al cierre. Los eventos comparten infraestructura Supabase; el aislamiento de autorización no equivale a infraestructura independiente.

Para cerrar Chiapas: primero REGISTROS_CHIAPAS_HABILITADOS=false y luego, si procede, sql/chiapas/cierre_apertura_20261025.sql. No borrar inscripciones para cerrar. La publicación desde main todavía puede reemplazar la versión de la rama; no hacer merge ni publicar main sin revisión.
