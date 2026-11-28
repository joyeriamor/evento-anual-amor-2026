# Entrega local de acceso offline 2.0.0

Preparada el 27 de noviembre de 2026 para una sola laptop Windows x64.

## Terminado

- Se recuperó el avance original WinForms/SQLite y se completó como versión 2.0.0.0.
- Selección explícita RADEV’S/Chiapas, con bases separadas.
- Inicio de sesión con usuario o correo, sesión protegida y renovación al conectar.
- Descarga completa de participantes y fotos privadas autorizadas para el evento.
- Activación de descarga únicamente cuando todas las fotos indicadas están guardadas;
  cancelación/fallo conserva la descarga anterior.
- Fotos JPEG/PNG/WebP, orientación de cámara y normalización local para visualizarlas.
- Nombre, folio, asesor, grupo y foto al leer el QR; habilitación manual de entrada.
- Validación local de confirmación, pago/cortesía, estado del QR y entrada previa.
- Entrada SQLite transaccional, durable y única por inscripción.
- Persistencia tras cerrar/reabrir, historial y respaldo consistente con fotos cifradas.
- Cola de sincronización, reintentos idempotentes y conflictos visibles sin perder datos.
- Revalidación de permisos, equipo, evento, QR y pago/cortesía al sincronizar.
- La descarga siguiente conserva las entradas pendientes y su paquete original.
- Ejecutable con runtime LTS incluido: no necesita instalar .NET ni descargar componentes.
- Código, migración, rollback, lock propio de Edge, pruebas y guía de operación.

## Verificación ejecutada

| Comprobación | Resultado | Entorno |
|---|---:|---|
| Aplicación Windows | 52 aprobadas | SQLite, DPAPI, imágenes y controles WinForms reales; Auth/HTTP simulados |
| SQL | 37 aprobadas | PostgreSQL PGlite local, 1,109 registros ficticios; incluye permisos, reintentos y rollback |
| Endpoint nuevo | 15 aprobadas | Handlers con Auth/RPC/Storage simulados |
| Guard de eventos | 252 aprobadas | HTTP local real y Supabase simulado |
| Tipado Edge | Aprobado | Deno, dependencias fijadas en lock separado |
| Lint del repositorio | Aprobado | Sin cambiar el frontend existente |
| Compilación Release x64 | Aprobada | SDK 10.0.404, Assembly/FileVersion 2.0.0.0, runtime incluido |
| Revisión visual | Aprobada | Captura de interfaz con persona y foto ficticias |

No se crearon participantes ni accesos reales. No se aplicó la migración ni se
publicó la Edge nueva. No se modificaron las funciones publicadas o las inscripciones.

## Pendiente de aprobación

Activar la migración y una sola Edge nueva, acceso-offline. Después verificar
Auth y Storage reales, descargar usando una cuenta autorizada y ensayar la
sincronización exclusivamente con una inscripción ficticia autorizada.
El plan y la reversión están en ACTIVACION.md.

No se ha probado un lector USB físico, una cámara QR ni un ciclo contra el backend
publicado nuevo. El lector funciona como teclado; las pruebas verificaron esa
entrada y el botón real de autorización. No se incluye lectura por cámara.

## Límites operativos

El modo sin internet usa la última descarga: no conoce cambios posteriores hasta
actualizarla. Usar una sola laptop; antes del evento, descargar de nuevo y verificar
fotos, fecha/hora y vigencia. Las entradas pendientes no se eliminan automáticamente.
El respaldo cifrado requiere conservar la misma cuenta de Windows y el identificador
del equipo. Las instrucciones están en LEEME.txt.

El ZIP original, el programa anterior, participante.csv, .bak y la base v1 se
conservan. La nueva versión guarda los datos por evento en una carpeta v2.
