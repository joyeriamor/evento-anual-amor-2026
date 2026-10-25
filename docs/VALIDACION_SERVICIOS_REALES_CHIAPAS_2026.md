# Avance de validación con servicios reales — Chiapas

24 de octubre de 2026. Continuación de `ca7b678` en la misma rama. Se ejecutaron pruebas acotadas autorizadas; no se desplegaron SQL, Edge o frontend, no se habilitaron inscripciones y no se modificaron cuentas, archivos, invitaciones ni participantes de RADEV’S.

## HTTP real con clave pública

Se ejecutó `scripts/verificar-servicios-solo-lectura.mjs` contra el proyecto autorizado `rkjlqxxmxbiciuhtpnpf`. Solo admite GET, no sigue redirecciones, fija el proyecto y rechaza claves de servidor. Se usó la clave publicable existente sin copiarla al código o al informe.

| Comprobación | Respuesta real | Interpretación |
|---|---|---|
| Configuración pública Auth | 200 | Control positivo: API alcanzable con la clave pública |
| Auth sin sesión | 401 | Consulta de usuario rechazada |
| Auth con token inválido | 403 | Consulta de usuario rechazada |
| Comprobante ficticio no creado, sin sesión | 400 / NoSuchKey | Ruta inexistente no descargable; no acredita autorización de un objeto existente |
| Comprobante ficticio no creado, token inválido | 400 / AccessDenied | Solicitud denegada |
| Foto ficticia no creada, sin sesión | 400 / NoSuchKey | Misma limitación de objeto inexistente |
| Foto ficticia no creada, token inválido | 400 / AccessDenied | Solicitud denegada |

Resultado: **7/7 sondas HTTP**. Evidencia: `RESULTADO_HTTP_SERVICIOS_20261024.json`. Las rutas Storage usan exclusivamente el UUID de Chiapas, un identificador aleatorio de ensayo y `no-creado.png`. No se subió ni firmó ningún archivo, se enumeraron objetos o se invocaron endpoints de negocio. No se iniciaron sesiones ni se consumió el limitador de login/registro.

Hubo un primer intento sin salida de red que registró 0/7 fallos de transporte en almacenamiento temporal; no se contó como resultado aprobado. La ejecución posterior con acceso de red autorizado es la evidencia real versionada. Los códigos 429, fallos de transporte y errores de servidor se consideran fallos, nunca rechazos de autorización aprobados. Un fallo del control positivo invalida la conclusión global aunque haya respuestas 401.

Estas sondas no prueban aislamiento por evento, RLS sobre archivos existentes, roles activos o sesiones válidas. Auth y Storage son servicios compartidos: no equivalen a servicios separados por evento. Las solicitudes pueden generar logs técnicos en Supabase aunque no escriban datos de negocio.

## Vault real dentro de una transacción revertida

Se comprobó primero la firma vigente de `vault.create_secret` y `vault.update_secret`. El ensayo `sql/security/ensayo_vault_chiapas_rollback.sql` creó un secreto aleatorio bajo un nombre único de ensayo Chiapas; consultó/descifró únicamente su ID recién creado, lo actualizó y ejecutó ROLLBACK.

Resultado real del servidor: **APROBADO, 6 comprobaciones, `rollback_sin_secreto_ficticio=true`**:

1. Creación devuelve un ID nuevo.
2. El valor almacenado es distinto del texto ficticio original.
3. La recuperación mediante Vault coincide con ese texto.
4. La actualización recupera el nuevo valor, distinto del anterior.
5. El cifrado actualizado cambia y sigue siendo distinto del texto actualizado.
6. Después del ROLLBACK no existe el secreto del ensayo.

Evidencia y SHA-256 del SQL exacto: `RESULTADO_VAULT_REAL_20261024.json`. No se listaron ni descifraron secretos existentes. No hubo DDL ni escrituras en public, auth o storage. El ensayo sí escribió transitoriamente su propio secreto ficticio en Vault antes del ROLLBACK; no se presenta como una consulta de solo lectura. No crea invitaciones ni valida por sí solo los permisos o la integración de las RPC de QR de la aplicación.

El archivo es un ensayo autorizado, **no una migración**. No ejecutarlo automáticamente ni incorporarlo al despliegue. Tiene límites de tiempo, aborta si su nombre ya existe y no modifica un secreto encontrado previamente. Requiere permiso explícito de uso de Vault si se repite fuera del alcance actual.

## Verificación local y reproducción

`tests/chiapas/servicios-solo-lectura.test.mjs` aprobó **11 comprobaciones locales** de las restricciones del verificador: destino fijo, GET sin cuerpo, claves permitidas, ausencia de llamadas a negocio/RADEV’S, rechazo de errores y ausencia de credenciales en los resultados. Es una prueba con respuestas simuladas y está incorporada a la suite local. ESLint también finalizó con código 0. La suite local nunca ejecuta las sondas remotas automáticamente.

Para repetir las sondas reales con autorización, desde la raíz del proyecto:

```
node scripts/verificar-servicios-solo-lectura.mjs --real-read-only RUTA_SEGURA_ENV SALIDA_NUEVA.json
```

El archivo de configuración solo necesita `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`. No suministrar service_role, contraseñas o sesiones de usuarios. La salida debe ser nueva; se rechaza sobrescribirla. No registrar el contenido del archivo de configuración ni subirlo al repositorio.

Referencias oficiales consultadas: [descargas Storage](https://supabase.com/docs/guides/storage/serving/downloads), [buckets privados](https://supabase.com/docs/guides/storage/buckets/fundamentals) y [Vault](https://supabase.com/docs/guides/database/vault).

## Estado operativo y siguiente requisito

El usuario indicó dejar sin cambios el perfil activo sin asignación: **se ignora operativamente, no se elimina ni recibe permisos**. El guard seguirá negándole acceso. Esa decisión resuelve la revisión de ese perfil; no se modificó ningún registro para reflejarla.

Siguen pendientes las pruebas completas: sesión válida y revocación de cuentas ficticias Chiapas; roles y asignaciones activos/inactivos; un archivo ficticio real con firma/lectura autorizadas y rechazo por evento; emisión, recuperación/reemisión y validación de QR por las RPC/Edge de la versión aprobada; limpieza de los recursos ficticios; frontend contra esos servicios.

El conector disponible permite consultar SQL y administrar Edge, pero no ofrece operaciones Auth Admin para crear cuentas ficticias. El archivo local solo contiene claves públicas. No se instalarán endpoints privilegiados ni se escribirán manualmente tablas internas de Auth para suplir ese acceso.

El requisito concreto para continuar la prueba integral es un entorno administrativo seguro que permita crear y limpiar exclusivamente las cuentas ficticias de Chiapas, o esas cuentas provisionadas por el titular con sus asignaciones. Las claves privadas no deben enviarse por chat. Además, las dependencias SQL/Edge nuevas todavía requieren aprobación concreta antes de publicarse; sin ellas no puede acreditarse el flujo integral del código local.

No quedan verificaciones locales pendientes para este avance. Las pruebas previas de build, aislamiento, catálogo, etapas, rollback y Chrome conservan el alcance documentado en sus informes; las sondas nuevas no las sustituyen ni convierten simulaciones en integración real.
