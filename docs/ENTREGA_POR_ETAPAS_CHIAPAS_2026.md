# Entrega local por etapas — Chiapas y RADEV’S

24 de octubre de 2026. Continuación de `2a67c80` en `feature/chiapas-evento-2026`.
La instrucción adjunta del usuario vuelve a limitar el trabajo al desarrollo y preparación locales: ninguna publicación sin aprobación. No se aplicaron cambios persistentes en Supabase, no se crearon cuentas ni archivos de prueba y no se publicaron Edge Functions o frontend durante esta continuación.

## Estado del desarrollo

Se conservan los pagos, cortesías, QR, cupos, accesos, roles y frontend entregados y probados anteriormente. El informe `INFORME_CHIAPAS_2026_LOCAL.md` detalla sus pruebas y límites. El commit original `8113458` se conserva en el historial; los commits posteriores no deben descartarse para volver a esa base.

La separación es lógica por evento dentro de infraestructura compartida. No equivale a dos proyectos independientes ni garantiza ausencia absoluta de fallos. Las rutas originales que todavía están publicadas no adquieren automáticamente las protecciones del código local.

## Paquetes SQL alternativos para revisión

En `sql/entrega_por_etapas/` hay tres etapas transaccionales, cada una con rollback separado y un manifiesto de firmas y hashes. **Son una alternativa a la migración consolidada, no pasos adicionales a ella.** Se mantienen fuera de `supabase/migrations` para evitar que una publicación automática ejecute ambas rutas. No ejecutar `db push` como sustituto de aprobar y registrar la ruta elegida. Si se aprueba la ruta por etapas, convertir esos paquetes a migraciones CLI únicas y retirar/sustituir la consolidada de esa entrega mediante un cambio revisado antes de publicar; no cambiar retroactivamente un historial aplicado.

| Orden | Archivo | Alcance y dependencias |
|---|---|---|
| 1 | `01_chiapas.sql` | Añade únicamente las seis funciones con nombre Chiapas: emisión interna, pago personal/admin, cortesía, recuperación y bandejas paginadas. No cambia funciones existentes, políticas, privilegios de tablas ni buckets. Depende de la estructura catalogada, de `usuarios_eventos` y de Vault existentes. **No basta por sí sola para abrir u operar Chiapas.** |
| 2 | `02_compartidos.sql` | Protección de QR por evento, perfiles y grupo, registros públicos/prueba, trigger de cupo, RLS y Storage. Incluye permisos mínimos de service_role sobre usuarios_eventos. Afecta recursos usados por ambos eventos; necesita revisión y autorización expresas, aunque no cambie sus filas o estados. |
| 3 | `03_protecciones_radevs.sql` | Pago admin/personal, cortesías, emisión/recuperación RADEV’S, bandejas RADEV’S y wrappers QR legacy. Conserva contratos; exige asignación activa y evita cruces. Depende del bloque compartido. Pendiente de autorización de publicación. |

Cada etapa comprueba las definiciones y ACL esperadas de las funciones existentes que modifica, y la ausencia de las funciones que crea. Cada rollback comprueba las versiones instaladas de esas funciones antes de restaurarlas. No omitir los controles ante drift.

El generador y los paquetes usan el catálogo de 24/10/2026. Estos controles no sustituyen una comparación completa del catálogo real, políticas, tablas, triggers, ACL y buckets inmediatamente antes de publicar. Un cambio de estructura o de permisos puede requerir regenerar y repetir la validación.

**Reversión:** restaurar primero frontend y Edge a sus versiones respaldadas; después ejecutar `03_protecciones_radevs_rollback.sql`, `02_compartidos_rollback.sql`, `01_chiapas_rollback.sql`, en ese orden y solo para etapas instaladas. La etapa 2 restaura las políticas, flags RLS, permisos de usuarios_eventos y visibilidad de buckets catalogados. No borrar operaciones de negocio posteriores. Las seis funciones Chiapas se retiran únicamente al revertir su etapa. Los rollback son transacciones independientes: cualquier error exige detenerse y revisar, no continuar con la siguiente etapa.

## Edge Functions y frontend

| Grupo | Funciones locales |
|---|---|
| Exclusivas Chiapas | `validar-pago-chiapas`, `administrar-invitacion-chiapas`, `bandejas-admin-chiapas`, `bandeja-personal-chiapas`, `registrar-participante-chiapas` |
| Originales RADEV’S | `validar-pago`, `administrar-invitacion`, `bandejas-admin`, `bandeja-personal`, `consultar-acceso`, `registrar-participante`, `registrar-participante-v2` |
| Compartidas | `_shared/evento.ts`, `consultar-acceso-evento`, `detalle-participante`, `gestionar-usuarios`, `iniciar-sesion-usuario`, `listar-asesores-registro`, `listar-participantes`, `registrar-prueba-admin`, `resumen-accesos`, `resumen-cupo-evento`, `verificar-personal` |

Los archivos compartidos se incluyen en cada bundle que los importe; no se publican solos. La clasificación identifica el impacto de despliegue, no elimina dependencias. El frontend único depende de funciones originales y compartidas: publicar solo los cuatro endpoints administrativos Chiapas no completa sus flujos.

Antes de publicar, respaldar y comparar cada función vigente con la local: las versiones publicadas y locales no son necesariamente equivalentes. Revisar cuerpos, contratos y verify_jwt. Preservar la verificación propia de JWT donde corresponda y los endpoints públicos de login/registro. No cambiar configuración global de Auth ni secretos o buckets compartidos como parte de una prueba Chiapas.

**Orden coordinado propuesto, pendiente de aprobación:** refrescar catálogo y respaldos; aplicar las tres etapas SQL aprobadas; publicar Edge con sus dependencias y contratos revisados; publicar frontend; comprobar los flujos autorizados. La activación de Chiapas permanece bloqueada hasta cerrar el aislamiento de todas las rutas originales y compartidas. No habilitar inscripciones como consecuencia del despliegue.

## Pruebas y permisos que faltan

La suite local sigue utilizando servicios simulados donde se indica. Las 31 comprobaciones anteriores con ROLLBACK sí se ejecutaron en PostgreSQL de Supabase, únicamente con pg_temp; no acreditan Auth, Storage o Vault reales.

Para pruebas integrales Chiapas se necesita:

- Acceso autorizado a Auth Admin para crear, revocar sesiones y eliminar únicamente identidades ficticias Chiapas, sin usar ni modificar cuentas RADEV’S. Las credenciales locales encontradas son públicas; no habilitan Auth Admin.
- Un administrador ficticio de Chiapas y perfiles de personal con asignaciones exclusivamente Chiapas. La provisión de usuarios/perfiles debe realizarse por la API administrativa admitida y procedimientos revisados, sin escrituras manuales en el esquema interno Auth.
- Acceso servidor a Storage para subir, firmar, descargar y eliminar únicamente archivos de prueba bajo un prefijo único de Chiapas. No cambiar permisos o visibilidad de buckets para facilitar la prueba. Probar rechazo a sesiones inválidas/inactivas y a archivos ajenos usando únicamente recursos ficticios; nunca descargar comprobantes RADEV’S.
- Capacidad de invocar las RPC Chiapas aprobadas para emitir, recuperar y reemitir QR con Vault real. Solo se crearán secretos asociados a invitaciones ficticias; se comprobará su limpieza por ID exacto, sin listar ni descifrar secretos de invitaciones existentes.
- Autorización específica de la versión a desplegar y de los datos ficticios a crear. No pedir claves por chat: utilizar un entorno administrativo seguro o provisión realizada por el titular. No instalar un endpoint privilegiado de pruebas accesible públicamente para suplir credenciales faltantes.

El ensayo requiere un identificador único, inventario previo de IDs creados y limpieza en orden de dependencias con verificaciones de evento. Revocar sesiones, quitar objetos/secretos exactos y eliminar las cuentas de ensayo; no usar borrados por rangos, teléfonos, fechas o coincidencias de nombre. La limpieza también es una operación real: documentar cualquier fallo y no declarar finalizada la prueba si quedan residuos. No escribir, generar QR, registrar entradas ni usar cuentas reales de RADEV’S para las comprobaciones cruzadas.

La autorización de pruebas ficticias anterior no se interpreta como autorización para modificar recursos RADEV’S ni para publicar los paquetes actuales. Con la instrucción adjunta más reciente, la publicación continúa pendiente de aprobación explícita.

## Reproducción local de la separación

```
node scripts/preparar-entrega-etapas.mjs
node tests/chiapas/entrega-etapas.integration.mjs
npm run test:local
```

El generador no conecta a Supabase. La prueba reconstruye el catálogo en PostgreSQL embebido, compara la salida de las tres etapas con la migración consolidada, verifica que la etapa exclusiva de Chiapas no altere recursos preexistentes, revierte cada etapa y compara definiciones, ACL, políticas, flags y buckets. También comprueba el rechazo de reinstalación y drift sin cambios parciales. Auth/Storage/Vault siguen siendo adaptadores locales en esta prueba.

## Resultado de esta continuación

La ejecución completa de `scripts/verificar-local.cjs` finalizó con código 0: lint, tipos frontend, build, comprobación Deno de Edge, pruebas administrativas existentes 17/14/19, matriz de aislamiento 197, perfiles 10, acceso legacy 8, SQL sintético 33, catálogo 77, etapas nuevas 17, ensayo pg_temp local 31 y frontend E2E 10. El E2E usó Chrome real y Supabase HTTP simulado. No se repitió el ensayo remoto ni se realizaron pruebas reales nuevas de Auth, Storage o Vault.

Al comprobar los rollback por etapas se detectó que el constructor local del catálogo omitía el privilegio PostgreSQL `MAINTAIN`; se incorporó para reproducir el ACL catalogado y comparar la restauración completa. Esto modifica exclusivamente el entorno de pruebas, no los permisos en producción.

Queda terminado el desarrollo local y la preparación separada. Faltan la comparación final de versiones publicadas, el acceso administrativo seguro para pruebas reales, su ejecución y limpieza, la aprobación concreta de las etapas compartida/RADEV’S y la publicación coordinada de SQL, Edge y frontend. Las inscripciones de Chiapas no se habilitan con esta entrega.
