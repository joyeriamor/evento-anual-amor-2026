# Incidencia controlada de preflight y corrección de ACL

Durante la publicación autorizada se instaló la etapa 1 Chiapas y la etapa 2 abortó en su preflight: esperaba un ACL explícito owner-only en impedir_sobrecupo_evento(), mientras el catálogo real conserva proacl=NULL (permisos predeterminados PostgreSQL). No se forzó el control.

Se ejecutó satisfactoriamente el rollback de la etapa 1; se verificó que no quedaban funciones Chiapas ni crear_perfil_evento_interno. La etapa 2 no ejecutó sus cambios y no se modificaron datos ni funciones RADEV’S en ese intento. El historial del servidor conserva tanto la aplicación inicial como su reversión; no se borraron esos registros.

La causa estaba en el constructor local del catálogo: después de recrear cada función revocaba permisos aun cuando el snapshot indicaba NULL. Se corrigió para preservar esos permisos predeterminados y se añadió una comparación de las 29 ACL originales. Los rollback conservan NULL para las funciones cuyos permisos no cambian; no convierten valores predeterminados en grants explícitos.

Se regeneraron las etapas y los paquetes, manteniendo sus controles de drift. Las dos variantes aprobaron 46 comprobaciones cada una (29 ACL originales más las 17 previas), y la suite completa finalizó con código 0, incluidos 13 E2E y 21 de build estático. Esto no sustituye las pruebas reales con la cuenta ficticia ni declara un despliegue posterior terminado.

## Segundo intento y bloqueo automático

Con el preflight corregido se aplicaron las etapas 1 y 2. La revisión automática rechazó la etapa 3 por considerar insuficiente la autorización concreta de RADEV’S. No se intentó ejecutar esa etapa por otra vía. Se revirtieron las etapas 2 y 1; una primera solicitud de reversión devolvió requestState expirado, se comprobó que no había aplicado cambios y se repitió como operación independiente con éxito.

Después de restaurar se verificaron las 29 definiciones y ACL originales, las dos políticas y los permisos efectivos de usuarios_eventos. El orden textual de grantees en el ACL de esa tabla cambió, pero las entradas y privilegios coinciden; no se modificó catálogo interno para forzar un orden. No se publicaron Edge ni frontend. La cuenta Auth ficticia creada por el usuario permanece sin perfil/asignación. Se solicitó aprobación explícita para la etapa 03 y sus Edge antes de continuar. El historial de aplicaciones y reversión se conserva, no se elimina para simular que no hubo intentos.

El usuario respondió posteriormente: «Sí, autorizo esa etapa y sus Edge». La aprobación explícita de la etapa RADEV’S y sus Edge queda recibida. Se retomará la publicación desde el estado restaurado y se documentará el resultado, sin volver a solicitar aprobación genérica.
