# Activación del acceso offline 2.1.0

## Alcance preparado

Aplicación Windows para una sola laptop; mantiene el avance de WinForms y SQLite
del ZIP original. Descarga el evento completo (sin límite REST de 1,000 filas)
y fotografías. Las fichas, fotos y QR pendientes se cifran con DPAPI CurrentUser.
La contraseña no se almacena. La sesión para operaciones online también usa DPAPI.
Solo se distribuye una clave **publicable**; no hay claves service_role.

RADEV’S y Chiapas usan bases independientes. El formato QR es el existente:
64 caracteres hexadecimales, comparados mediante SHA-256 sin cambiar el contenido.
No se generan ni reemplazan invitaciones. No hay datos de demostración cargados
automáticamente ni importación automática del participante.csv original.

## Estado de activación

El usuario autorizó la activación del módulo offline y un ensayo ficticio.
Se aplicó la migración y se publicó acceso-offline v1 con verify_jwt=true.
Las dos tablas nuevas no conceden acceso directo a anon/authenticated;
las dos RPC públicas comprueban identidad, rol y asignación activos.
El helper no es ejecutable directamente por esos roles.
Las 57 funciones SQL y 33 Edge anteriores conservaron sus definiciones/versiones.
El ensayo real y su limpieza se detallan en INFORME.md.

## Procedimiento de publicación y futuras reinstalaciones

Las nuevas modificaciones de producción requieren autorización explícita.
No volver a aplicar una migración que ya aparece instalada.

1. Respaldar las definiciones actuales y confirmar que no existen objetos
   llamados offline_paquetes, offline_operaciones u offline_*.
2. Aplicar únicamente la migración
   supabase/migrations/20261128025528_acceso_offline.sql.
   Crea dos tablas privadas con RLS, un índice y tres funciones nuevas.
   No altera tablas, funciones ni registros existentes.
3. Publicar únicamente la Edge acceso-offline con verify_jwt=true, su lock
   y el guard compartido incluido como dependencia de esa función.
   No volver a publicar las Edge anteriores.
4. Verificar Auth real con una cuenta administradora/asignada, descargar,
   abrir sin internet y comprobar fotos/estados sin autorizar ingresos reales.
5. Para probar escritura integral, usar exclusivamente una inscripción ficticia
   autorizada y su QR; comprobar reintento y limpiar solo ese ensayo al terminar.
6. Distribuir la carpeta Programa al equipo de recepción; preparar una descarga
   nueva cerca del evento y confirmar fotos/pendientes antes de desconectar.

La cuenta debe ser administrador o acceso, activa y asignada al evento tanto al
descargar como al sincronizar. El servidor obtiene la identidad del JWT validado.
Cada paquete está vinculado a usuario, equipo y evento, y contiene los IDs de
invitaciones de esa descarga. No se aceptan IDs de operador del cliente.
El endpoint firma únicamente fotos obtenidas del conjunto de ese evento.

La sincronización añade accesos existentes en el contrato original, con la hora
local de captura validada dentro de la vigencia del paquete. Registra aparte la
hora de recepción. Revalida pago/cortesía e invitación tras bloquear la inscripción,
con el mismo orden de bloqueo que el ingreso online. Operaciones repetidas con
el mismo ID y datos devuelven el resultado anterior; reutilizar ID con otros datos
se rechaza. Si ya existe ingreso de otra invitación de esa persona no inserta otro.

Los paquetes vencen al terminar el día del evento en America/Mexico_City. Se permite
recibir entradas capturadas durante su vigencia hasta siete días después para
recuperar pendientes. No hay trabajos automáticos de envío ni limpieza de datos.
Una descarga no conoce revocaciones, pagos o entradas posteriores mientras esté
desconectada; el servidor sí vuelve a comprobarlos al recibir los pendientes.

## Reversión

Primero sincronizar o resguardar todos los pendientes; retirar la Edge nueva.
Después revisar y ejecutar supabase/rollbacks/20261128025528_acceso_offline.sql.
Elimina solo los objetos offline nuevos, no las entradas ya recibidas en accesos.
Los endpoints y el frontend online siguen usando los contratos anteriores.

## Pruebas

- offline/AMOR.AccesoOffline.Pruebas: SQLite, DPAPI, imágenes y controles WinForms
  reales en Windows. Auth y HTTP se simulan; nunca se usan cuentas o QR reales.
- tests/offline/sql.integration.mjs: PostgreSQL PGlite local, con 1,109 registros
  ficticios de un evento, permisos/aislamiento, revalidación, idempotencia y rollback.
- tests/offline/edge.test.cjs: handlers con Auth/RPC/Storage simulados.
- tests/chiapas/aislamiento-eventos.test.cjs: transporte HTTP local real,
  con Supabase simulado y el guard existente.
- Deno check de la Edge nueva con lock separado; no modificar el lock global.

Las pruebas locales no sustituyen Auth, descarga, Storage y sincronización contra
el servicio publicado. Esa verificación requiere la activación anterior.
