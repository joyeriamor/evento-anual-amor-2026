# Publicación preparada — accesos y entrega al operador

24 de octubre de 2026, hora de México. Versión funcional base: `8f2b8a9`, rama `feature/chiapas-evento-2026`.

## Autorización vigente y estado

El usuario autorizó publicar y realizar las pruebas: «ok hazlo y debes realizar las pruebas». Posteriormente indicó que subirá la rama desde su máquina virtual, que usa otra cuenta GitHub. **No falta volver a pedir autorización de publicación.** Faltan la entrega de la rama por el operador y el acceso administrativo seguro para las pruebas positivas pendientes.

No se ejecutaron apply_migration, despliegues Edge, push, merge, cambios de inscripción, altas de cuentas, cambios de asignación ni operaciones sobre participantes/pagos de RADEV’S durante esta preparación. No se publicó el frontend. La publicación coordinada no se inició parcialmente porque no puede completarse y verificarse con los accesos actuales.

## Verificaciones previas reales

- GitHub conectado como `iBoss170589`: el repositorio `joyeriamor/evento-anual-amor-2026` informa pull=true y push=false. La comprobación alternativa `git push --dry-run` tampoco encontró credenciales HTTPS utilizables; no subió referencias. El operador realizará esa subida desde la VM.
- Supabase: el conector puede administrar SQL y Edge, pero no ofrece Auth Admin. El navegador disponible redirige el panel Auth a iniciar sesión. No se usaron credenciales de otro evento ni escrituras manuales en auth.users para suplirlo.
- El catálogo actual sigue coincidiendo en las 29 funciones públicas, hashes, ACL y SECURITY DEFINER, además de flags/permisos de las tablas, políticas y visibilidad de buckets. Las 17 Edge publicadas conservan código, versión y verify_jwt de la revisión anterior. No hay migraciones registradas mediante Supabase en el historial consultado.
- RADEV’S permanece `activo` y Chiapas `borrador`. No se modifica el perfil sin asignación que el usuario pidió ignorar.
- Se consultaron los asesores automáticos de seguridad y rendimiento. Hay avisos preexistentes; no se cambiaron parámetros globales de Auth, funciones, índices o permisos para silenciarlos. El resumen está en el respaldo operativo. Los avisos de SECURITY DEFINER requieren interpretar los guards/contratos; no se pueden resolver desactivando indiscriminadamente funciones necesarias.

## Respaldo duradero verificado

Directorio excluido de Git por la regla existente `*.local`:

`C:\PROYECTOS\FIESTAANUAL26\RESPALDO_PUBLICACION_20261024.local`

En el equipo de trabajo está montado como `/Volumes/Proyectos/FIESTAANUAL26/RESPALDO_PUBLICACION_20261024.local`.

Contiene el código recuperado de las 17 Edge publicadas, definiciones SQL/ACL, estructura catalogada, rollback completo, flags de eventos y frontend público anterior. La página pública respondió HTTP 200 y se respaldaron seis archivos, incluidos HTML, JavaScript, CSS y recursos. Cada copia se verificó por SHA-256. No es un volcado de participantes o pagos y no incluye contraseñas ni claves privadas. No se sobrescribió un respaldo previo.

También se conserva por separado `frontend-candidato/`: compilación candidata con las variables **públicas** reales del archivo existente y el mismo indicador de inscripción del workflow publicado. Chiapas mantiene su bloqueo independiente. No es el dist ficticio de la suite local y no se ha publicado. Su prueba de Chrome sobre servidor estático local aprobó 21 comprobaciones, bloqueando toda red externa; no hizo operaciones en Supabase.

No borrar el respaldo al subir Git. No subir `RESPALDO_PUBLICACION_20261024.local`, archivos de entorno ni credenciales al repositorio.

## Paquete definitivo por etapas

`supabase/paquete_publicacion_20261024/` contiene migraciones creadas realmente mediante Supabase CLI 2.122.0 en un workspace temporal no enlazado:

1. `20261025013242_chiapas_funciones_independientes.sql`
2. `20261025013244_aislamiento_compartido_eventos.sql`
3. `20261025013246_protecciones_radevs.sql`

Las fechas de archivo son UTC. Los cuerpos son copias exactas de las etapas revisadas, con sus preflights y transacciones. `rollback/` conserva la reversión de cada etapa; aplicarlas inversamente 3 → 2 → 1 para las etapas efectivamente instaladas. `manifest.json` incluye hashes y orden. `edge-manifest.json` identifica 23 bundles y verify_jwt; excluye la ruta no publicada `registrar-participante`, usada solo por páginas de prueba.

**No ejecutar `supabase db push` desde la raíz.** Allí permanece la migración consolidada alternativa; aplicar ambos caminos es incorrecto. El paquete está aislado deliberadamente para revisión y aplicación controlada. Si se publica con MCP, sincronizar los identificadores de migración con las versiones efectivamente registradas por el servidor antes de entregar la historia final. No inventar versiones ni reparar el historial como si SQL no ejecutado ya estuviera instalado.

Antes de aplicar: refrescar nuevamente catálogo/versiones, verificar capacidad de pruebas y restauración y contrastar los hashes del paquete. No omitir un preflight que detecte drift.

## Pruebas realizadas sobre la entrega

- 17 comprobaciones SQL sobre las etapas de revisión: aprobadas.
- 17 comprobaciones sobre los archivos CLI exactos del paquete definitivo: aprobadas. Comparan resultado final con la consolidada, conservación de recursos existentes en etapa Chiapas, rollback exacto por etapa y rechazo de drift/reinstalación sin efectos parciales.
- ESLint: código 0.
- Build candidato con configuración pública real: aprobado. La compilación avisa de un chunk mayor de 500 kB; no se ocultó el aviso ni se cambió comportamiento para eliminarlo.
- 21 comprobaciones Chrome sobre ese candidato servido como archivos: aprobadas, con red externa bloqueada.

Estas pruebas no sustituyen las pruebas positivas Auth/Storage/QR contra la versión desplegada. La suite completa y las sondas reales anteriores mantienen sus alcances documentados; no se afirman nuevas pruebas de producción con cuentas válidas.

## Instrucciones para subir desde Windows / VM

Abrir PowerShell y ejecutar:

```powershell
Set-Location 'C:\PROYECTOS\FIESTAANUAL26'
git branch --show-current
git log -1 --oneline
git push origin feature/chiapas-evento-2026
```

La rama debe ser exactamente `feature/chiapas-evento-2026`. El último commit debe coincidir con la entrega indicada en el chat. Si no coincide, detenerse y revisar antes de subir.

Este push envía los commits existentes; no incluye los archivos modificados sin commit. **No ejecutar `git add .`, `git commit -a`, `git reset`, `git clean`, `git push --force` ni merge a main.** Hay archivos y respaldos del usuario que se conservaron sin incorporarlos. El workflow inspeccionado se dispara automáticamente por push a main, no por subir esta rama.

Después del push, comunicar el resultado o el error, sin tokens. Todavía no ejecutar «Run workflow»: eso sí publicaría el frontend antes de instalar y validar sus dependencias.

## Secuencia restante de publicación

1. El operador sube la rama. Completar acceso administrativo seguro a Supabase para provisionar y limpiar únicamente las cuentas/archivos ficticios Chiapas. No compartir claves por chat.
2. Aplicar las tres etapas SQL y publicar los bundles revisados de forma coordinada, con respaldo disponible. Si falla la verificación, detenerse y ejecutar la reversión correspondiente; no continuar por inercia.
3. Ejecutar pruebas reales de sesión válida, roles y asignaciones, comprobantes propios/ajenos ficticios, pago/cortesía, generación/recuperación/reemisión de QR, acceso y limpieza. No utilizar participantes o cuentas reales RADEV’S para esos ensayos.
4. Solo después, ejecutar manualmente el workflow existente desde la rama de entrega, sin merge a main, y verificar la versión realmente publicada, los enlaces directos y los estados de inscripción. El workflow deberá usar las variables públicas correctas; nunca publicar el build ficticio generado por test:local.
5. Conservar evidencia, versiones aplicadas, resultado del workflow, limpieza y rollback operativo. La apertura de inscripciones Chiapas sigue siendo una decisión separada.

El acceso de SQL/Edge del conector no reemplaza el permiso de publicación GitHub ni Auth Admin. Esta preparación está terminada; la publicación sigue pendiente de esos pasos operativos, no de otra confirmación genérica.
