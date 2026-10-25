# Incidencia controlada de preflight y corrección de ACL

Durante la publicación autorizada se instaló la etapa 1 Chiapas y la etapa 2 abortó en su preflight: esperaba un ACL explícito owner-only en impedir_sobrecupo_evento(), mientras el catálogo real conserva proacl=NULL (permisos predeterminados PostgreSQL). No se forzó el control.

Se ejecutó satisfactoriamente el rollback de la etapa 1; se verificó que no quedaban funciones Chiapas ni crear_perfil_evento_interno. La etapa 2 no ejecutó sus cambios y no se modificaron datos ni funciones RADEV’S en ese intento. El historial del servidor conserva tanto la aplicación inicial como su reversión; no se borraron esos registros.

La causa estaba en el constructor local del catálogo: después de recrear cada función revocaba permisos aun cuando el snapshot indicaba NULL. Se corrigió para preservar esos permisos predeterminados y se añadió una comparación de las 29 ACL originales. Los rollback conservan NULL para las funciones cuyos permisos no cambian; no convierten valores predeterminados en grants explícitos.

Se regeneraron las etapas y los paquetes, manteniendo sus controles de drift. Las dos variantes aprobaron 46 comprobaciones cada una (29 ACL originales más las 17 previas), y la suite completa finalizó con código 0, incluidos 13 E2E y 21 de build estático. Esto no sustituye las pruebas reales con la cuenta ficticia ni declara un despliegue posterior terminado.
