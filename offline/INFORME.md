# Acceso offline 2.1.0

Preparada y validada el 27–28 de noviembre de 2026 para una sola laptop Windows x64.

## Terminado

- Se recuperó el avance original WinForms/SQLite y se completó como versión 2.1.0.0.
- Selección explícita RADEV’S/Chiapas, con bases separadas.
- Inicio de sesión con usuario o correo, sesión protegida y renovación al conectar.
- Descarga completa de participantes y fotos privadas autorizadas para el evento.
- Activación de descarga únicamente cuando todas las fotos indicadas están guardadas;
  cancelación/fallo conserva la descarga anterior.
- Fotos JPEG/PNG/WebP, orientación de cámara y normalización local para visualizarlas.
- Muestreo JPEG antes de asignar memoria: admite la foto real de 32 MP sin cambiarla.
- Compatibilidad con JPEG antiguos sin marcador final; rechazo de imágenes ilegibles,
  conservando la descarga anterior.
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
| Aplicación Windows | 60 aprobadas | SQLite, DPAPI, imágenes y controles WinForms reales; Auth/HTTP simulados |
| SQL | 37 aprobadas | PostgreSQL PGlite local, 1,109 registros ficticios; incluye permisos, reintentos y rollback |
| Endpoint nuevo | 15 aprobadas | Handlers con Auth/RPC/Storage simulados |
| Guard de eventos | 260 aprobadas | HTTP local real y Supabase simulado |
| Tipado Edge | Aprobado | Deno, dependencias fijadas en lock separado |
| Lint del repositorio | Aprobado | Sin cambiar el frontend existente |
| Compilación Release x64 | Aprobada | SDK 10.0.404, Assembly/FileVersion 2.1.0.0, runtime incluido |
| Revisión visual | Aprobada | Captura de interfaz con persona y foto ficticias |

## Activación y ensayo real

Se aplicó únicamente la migración del módulo offline y se publicó una nueva
Edge acceso-offline v1. No se reemplazaron las 33 Edge ni las 57 funciones SQL
anteriores. Las tablas son privadas, con RLS y sin SELECT directo para usuarios.
Auth real, Edge y RPC rechazaron las solicitudes sin sesión.
La sesión real de hugo se usó desde el programa; contraseña y tokens no se
imprimieron, exportaron ni incorporaron al código o al paquete.

La prueba real descargó 532 fichas y 532 fotos de RADEV’S, y 92 fichas y 92 fotos
Chiapas (91 existentes y una ficticia). Se verificó que las listas no se mezclan.
Con el adaptador de red de Windows desconectado, se mostró la fotografía, se
registró una entrada ficticia, se bloqueó el segundo ingreso y el pendiente
persistió al reabrir. La red se restauró al terminar mediante un bloque finally.
Al reconectar, la sincronización real dejó cero pendientes y cero conflictos.
Repetir la misma operación no duplicó el ingreso: SQL confirmó un solo acceso.
El servidor rechazó el paquete Chiapas en RADEV’S y un dispositivo diferente.
No se autorizó ningún ingreso de una participante real.

Ensayo: EA26-2DDCB8EFA41F436885E0D1B675D8D812.
La limpieza permanente de su registro, dependencias y fotografía quedó preparada
con filtros exactos; requiere la confirmación final del navegador.
El lector USB físico sigue pendiente de comprobar en el equipo de recepción.
No se ha probado un lector USB físico ni una cámara. El lector funciona como
teclado; las pruebas verificaron esa entrada y el botón real de autorización.
No se incluye lectura por cámara.

## Límites operativos

El modo sin internet usa la última descarga: no conoce cambios posteriores hasta
actualizarla. Usar una sola laptop; antes del evento, descargar de nuevo y verificar
fotos, fecha/hora y vigencia. Las entradas pendientes no se eliminan automáticamente.
El respaldo cifrado requiere conservar la misma cuenta de Windows y el identificador
del equipo. Las instrucciones están en LEEME.txt.

El ZIP original, el programa anterior, participante.csv, .bak y la base v1 se
conservan. La nueva versión guarda los datos por evento en una carpeta v2.
