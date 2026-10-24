# FIESTAANUAL26 — cierre del desarrollo local

24 de octubre de 2026. Rama `feature/chiapas-evento-2026`.
Base inicial verificada: `8113458`, precedida de `645292d` y `53c1661`.
Se continuó desde los avances recibidos y desde los commits de entrega `aac8291`, `28980c3` y `790805d`.
Repositorio: `C:\PROYECTOS\FIESTAANUAL26`, montado en `/Volumes/Proyectos/FIESTAANUAL26`.

**El usuario eligió expresamente terminar solo el desarrollo local y rechazó crear una rama Supabase con costo.** Se completa ese alcance: código, migración y rollback locales, pruebas reproducibles y plan de despliegue. Esto no declara que el código nuevo esté desplegado ni que los servicios de producción hayan sido validados con él.

No se modificaron registros reales, estados de inscripción, esquema remoto, funciones publicadas ni almacenamiento real. Se realizaron consultas de catálogo en modo lectura. No se creó ninguna rama/proyecto Supabase, no hubo push, merge ni despliegue. Se conservaron los `.bak`, archivos sin seguimiento y cambios ajenos a esta entrega. No se copiaron filas personales, tokens de invitación ni secretos de producción a las fixtures.

## Operación implementada

- Selección entre RADEV'S Minatitlán y Fiesta Anual AMOR Chiapas mediante rutas separadas, con recuperación de sesión y comprobación de rol para el evento seleccionado.
- Participantes, ficha, pagos, comprobantes, cortesías, recuperación y reemisión de QR, bandejas de personal, escáner, historial, cupos y usuarios utilizan el evento correspondiente.
- Fechas y capacidades: RADEV'S, 6 diciembre 2026 y 1500; Chiapas, 19 diciembre 2026 y 500. Cuota de participantes de pago: $300. Se conservan las reglas existentes de cortesías y la exclusión de empleados en Chiapas.
- Las invitaciones identifican el evento correcto; Chiapas conserva sede y horario por definir. No se alteraron las opciones reales de inscripción. Chiapas permanece bloqueado en frontend y cerrado por defecto en backend.

## Protección de API, RPC y almacenamiento

Los 17 endpoints privados utilizan la capa común `supabase/functions/_shared/evento.ts`: JWT validado contra Auth, perfil y rol activos, asignación activa en `usuarios_eventos`, evento permitido, método y tamaño real del cuerpo. El contexto interno de evento se sobrescribe en servidor; los campos de administrador del cliente no establecen identidad.

Endpoints: `validar-pago`, `administrar-invitacion`, `bandejas-admin`, `bandeja-personal`, sus cuatro variantes Chiapas, `listar-participantes`, `detalle-participante`, `consultar-acceso`, `consultar-acceso-evento`, `resumen-accesos`, `gestionar-usuarios`, `registrar-prueba-admin`, `resumen-cupo-evento` y `verificar-personal`. Se revisaron también login, catálogo público de asesores y registros públicos.

Las consultas privadas filtran por evento antes de consultar relaciones o firmar archivos. Las RPC de pago filtran la pertenencia antes de revelar su estado. Los UUID específicos de RADEV'S y Chiapas se fijan en servidor. Las RPC compartidas de lectura comprueban el evento real de la inscripción y la asignación del usuario.

La auditoría de catálogo encontró y resolvió en el paquete local:

- Falta de SELECT/INSERT/UPDATE de `service_role` sobre `usuarios_eventos`, indispensable para los guards y altas de perfiles. Se incluyen únicamente esos permisos y su reversión exacta.
- `consultar_grupo_registro_admin(uuid)` sin asignación por evento. Se protege manteniendo su firma.
- La propuesta inicial del generador RADEV'S exigía administrador y rompía la emisión desde validadores. Se admite el validador activo y asignado; el generador permanece sin ejecución directa desde el navegador o service_role.
- Creación de perfil y asignación en pasos separados. La nueva RPC interna los crea junto con su auditoría en una transacción; si falla, la Edge elimina únicamente la cuenta Auth recién creada. No quedan perfiles huérfanos por fallos de asignación.
- RPC de registro y trigger con límites genéricos. Ahora fijan 1500/500 como máximos, respetan configuraciones menores, excluyen EMPLEADO en Chiapas y rechazan rutas de archivos de otro evento. Las firmas existentes se conservan.

Las cuentas nuevas quedan asignadas al evento seleccionado. La edición de una cuenta compartida activa con otro evento devuelve 409 para proteger su perfil y contraseña globales. El control del último administrador se limita al evento.

Las políticas propuestas restringen lecturas por asignación/rol y escrituras directas del navegador; los cambios pasan por Edge autorizadas o RPC protegidas. Fotos y comprobantes requieren relación con la inscripción autorizada. Se preserva el carácter privado de ambos buckets. El catálogo actual no tenía políticas de Storage concediendo lecturas anónimas; no se añaden permisos permisivos nuevos.

## Migración y rollback definitivos, preparados localmente

Archivo creado por Supabase CLI 2.122.0:

`supabase/migrations/20261024221610_aislar_eventos_radevs_chiapas.sql`

La migración única integra las propuestas de `sql/security/` y Chiapas en orden de dependencias, dentro de una transacción. Verifica los hashes de las 29 funciones públicas catalogadas y la ausencia de las nuevas antes de cambiar nada. Se evita la incompatibilidad de aplicar propuestas separadas cuyos controles esperaban aún las definiciones originales.

`sql/security/rollback_eventos_completo.sql` restaura las definiciones y ACL catalogadas, retira solo las políticas y funciones nuevas y restaura flags RLS, privilegios de asignación y visibilidad de buckets. No elimina registros ni pagos. Se ensayó después de crear datos ficticios y emitir/usar QR, verificando que dichos datos y los estados de eventos permanecen.

`npm run prepare:migration` regenera ambos archivos a partir de los fuentes y snapshots versionados. El generador únicamente escribe SQL local: no conecta, aplica ni despliega. No debe ejecutarse una propuesta suelta como sustituto de la migración consolidada. Antes de un despliegue futuro se debe refrescar el catálogo; cualquier drift bloquea la migración.

Snapshots estructurales, sin filas reales: `tests/fixtures/catalogo_esquema_20261024.json` y `catalogo_rpc_20261024.json`. Incluyen columnas, identidad, restricciones, índices, triggers, funciones, ACL y políticas. La reconstrucción local usa esa estructura y filas inventadas.

## Pruebas ejecutadas

| Verificación | Resultado | Qué se ejecutó |
|---|---:|---|
| Administración Chiapas existente | 17/17 | Handler real; Supabase simulado |
| Bandejas admin Chiapas existentes | 14/14 | Handler real; Supabase simulado |
| Bandeja personal Chiapas existente | 19/19 | Handler real; cero comprobantes RADEV'S firmados |
| Acceso Chiapas legacy | 8/8 | Handler real; backend simulado |
| Matriz de aislamiento | 197 aprobadas | 17 endpoints; Auth/DB simulados; transporte HTTP local real en dos solicitudes |
| Creación de perfiles | 10 aprobadas | Handler real; identidad desde JWT, RPC atómica y limpieza Auth; backend simulado |
| SQL sintético inicial | 33 aprobadas | PostgreSQL embebido real; esquema mínimo y datos sintéticos |
| Integración sobre catálogo real | 77 aprobadas | PostgreSQL y pgcrypto reales; esquema reconstruido, datos ficticios y adaptadores locales |
| E2E frontend | 10 aprobadas | Chrome real, servidor Vite aislado y respuestas Supabase simuladas |
| TypeScript frontend, lint y build | Aprobados | TypeScript 6.0.3, ESLint y Vite 8.3.4 |
| Tipos de Edge | Aprobados | Deno 2.9.6 real, dependencias congeladas en `supabase/edge-check.lock` |
| Instalación limpia | Aprobada | Dependencias resueltas desde package-lock en carpeta temporal |

Las 77 comprobaciones nuevas incluyen la migración íntegra **sin omitir preflights**, altas de ambos eventos con mismo teléfono, duplicados dentro del evento, perfiles atómicos, grupo ajeno, aprobación por ambos validadores, recuperación y reemisión, QR revocado/ajeno/duplicado, cifrado real en reposo mediante pgcrypto, máximos 1500/500 aun con configuración excesiva, rollback completo con comparación de hashes/ACL y rechazo sin efectos de una migración ante drift deliberado.

Auth, Storage y Vault en la integración SQL son **adaptadores locales**. El adaptador Vault cifra realmente mediante pgcrypto, pero no es la extensión Supabase Vault. Las pruebas no acreditan servicios Supabase reales ni concurrencia multisesión. No se ejecutaron operaciones de ensayo sobre producción, tampoco con ROLLBACK.

## Reproducción

Herramientas de prueba fijadas en package.json/package-lock: PGlite 0.5.11, Playwright 1.62.1 y Deno 2.9.6. No forman parte del bundle publicado. Los node_modules de Windows y el deno.lock del usuario se conservaron. El lock de comprobación de Edge es un archivo separado.

Después de `npm ci` e instalar un navegador de Playwright con `npx playwright install chromium`, ejecutar:

```
npm run test:local
```

Ese comando comprueba lint, tipos, build, Edge, seguridad, SQL y E2E. E2E levanta y termina su propio servidor en 127.0.0.1:5178, utiliza URL y clave ficticias y rechaza destinos no locales. Si el puerto está ocupado, aborta sin usar un servidor ajeno. Puede utilizarse un Chrome instalado mediante `FIESTA_CHROME_PATH`; así se ejecutó en esta sesión.

Comandos individuales: `npm run test:security`, `npm run test:sql`, `npm run test:catalog`, `npm run check:edge`, `npm run test:e2e`, `npm run lint` y `npm run build`.

## Despliegue futuro — fuera del cierre local autorizado

1. Refrescar el catálogo de producción en modo lectura y comparar con el snapshot. La migración aborta ante hashes distintos; no omitir controles para forzarla.
2. Con autorización para un entorno Supabase desechable, repetir pruebas de Auth, Storage, Vault y simultaneidad. Se rechazó ese recurso en esta sesión, por lo que no se creó ni facturó uno.
3. Revisar la migración consolidada y su rollback; respaldar funciones, permisos, políticas y configuración vigentes. Confirmar FOTO_BUCKET y credenciales del entorno sin exponer service_role en frontend.
4. Obtener aprobación explícita antes de aplicar SQL o publicar Edge/frontend en producción. Abrir inscripciones requiere una aprobación independiente.
5. Con aprobación, aplicar la migración consolidada; publicar las Edge con `_shared` y después el frontend. Comprobar RADEV'S primero y Chiapas después con pruebas autorizadas, conservando ambos estados de inscripción.
6. Ante regresión, restaurar las versiones previas de frontend/Edge y ejecutar el rollback estructural exacto. El rollback no es una reversión de operaciones de negocio posteriores al despliegue: no borra pagos ni accesos.

**Cierre:** desarrollo local completado y probado dentro del alcance elegido. Publicación, pruebas contra servicios Supabase reales y apertura de registros permanecen fuera de la autorización.
