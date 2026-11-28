# Acceso offline 2.2.0 · búsqueda por nombre completo

Preparado el 28 de noviembre de 2026 para una sola laptop Windows x64.

## Funcionalidad terminada localmente

- Búsqueda sin internet por nombres y ambos apellidos, con acentos o sin ellos,
  mayúsculas, espacios adicionales y apellidos en distinto orden.
- Resultados del evento seleccionado con nombre completo, folio, asesor, grupo y
  situación. Los homónimos requieren selección explícita; no se elige al primero.
- Revisión de la fotografía en la ficha y check obligatorio de identidad antes
  de habilitar el botón de ingreso sin QR. La búsqueda no registra entradas.
- Se mantienen confirmación, pago/cortesía, QR emitido/activo, vigencia y entrada
  previa. El ingreso por nombre bloquea después el QR y viceversa.
- Historial y cola distinguen QR de Nombre y fotografía. La cola conserva
  pendientes y sus IDs después de reiniciar, de perder una respuesta o de fallar
  el nuevo servicio. No inventa, recupera ni descarga QR en claro para buscar.
- Las bases v2 existentes agregan origen con valor heredado qr. Se conservan
  descargas, fotografías, entradas anteriores y pendientes de 2.1.
- Versión Assembly/FileVersion 2.2.0.0 con runtime incluido. No se borró la
  versión anterior, el avance original, archivos .bak ni archivos del usuario.

Los nombres permanecen cifrados en SQLite; la búsqueda descifra solamente en
memoria. Cada evento utiliza su base y su descarga vigente.

## Pruebas ejecutadas

| Comprobación | Resultado | Entorno |
|---|---:|---|
| Aplicación Windows | 105 aprobadas | SQLite, DPAPI, JPEG/WebP y controles WinForms reales; Auth/HTTP simulados |
| Nueva RPC por nombre | 37 aprobadas | PostgreSQL PGlite local, datos ficticios; permisos, aislamiento, reintentos y rollback |
| Nuevo endpoint por nombre | 16 aprobadas | Handlers con Auth/RPC simulados |
| HTTP del flujo manual | 14 aprobadas | Transporte y guard reales en localhost; Auth/RPC simulados |
| Regresión SQL QR | 37 aprobadas | PostgreSQL local |
| Regresión endpoint QR | 15 aprobadas | Handlers simulados |
| Tipado y lint | Aprobados | Deno check con lock propio congelado y ESLint del repositorio |
| Release Windows x64 | Aprobado | SDK 10.0.404, runtime 10.0.15, versión 2.2.0.0 |

Se probaron apellidos en orden inverso, acentos Unicode, homónimos, elección por
folio, evento cruzado, selección antigua al renovar descarga, foto ausente,
pago/estado no autorizables, carrera QR/nombre, pérdida de respuesta y migración
de una base 2.1 con una entrada QR pendiente. La interfaz real exigió el check,
mostró la foto ficticia y registró exactamente una entrada al pulsar el botón.

La lectura de códigos de un lector USB físico sigue pendiente en el equipo de
recepción. La búsqueda no necesita el lector. La verificación real anterior
2.1 cubrió Auth, Storage, descarga de ambos eventos, entrada ficticia con la red
Windows desconectada y sincronización QR; su ensayo fue limpiado. El nuevo
flujo por nombre se ha probado localmente y todavía requiere el ensayo real.

## Activación pendiente de autorización

El desarrollo no modificó datos reales, esquema de producción ni funciones
publicadas. El componente preparado agrega únicamente:

- RPC offline_sincronizar_manual, mediante la migración
  20261128144415_acceso_offline_manual.sql.
- Edge acceso-offline-manual, con verify_jwt=true y lock propio.

No reemplaza las funciones QR, de pagos, de invitaciones ni de acceso online.
El servidor revalida JWT, perfil/rol/asignación activos, paquete del usuario,
equipo y evento, pareja registro/invitación incluida en la descarga, foto
existente, estado y pago/cortesía actuales y ausencia de ingreso previo.
Las operaciones se auditan con origen=nombre y conservan la idempotencia.

Falta autorización explícita para publicar ese componente y ejecutar un ensayo
con un registro y foto ficticios, limpiando exclusivamente ese ensayo al acabar.
El plan y el rollback están en ACTIVACION.md. El programa conserva los ingresos
por nombre si aún falta activar su servicio; no confirma sincronización hasta
recibir una respuesta positiva. Utilizar 2.2 o posterior para esos pendientes.
