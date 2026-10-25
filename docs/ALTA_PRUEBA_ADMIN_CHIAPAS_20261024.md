# Alta administrativa ficticia Chiapas — corrección previa al despliegue

Se detectó al preparar la prueba integral que registrar-prueba-admin estaba fijado a RADEV’S y que el formulario Chiapas permanecía bloqueado también para ensayos administrativos. No se usó ese endpoint para crear registros en RADEV’S.

Se conserva intacto el endpoint original y se añade registrar-prueba-admin-chiapas, con JWT verificado, administrador activo asignado exclusivamente al evento autorizado, UUID Chiapas fijo, archivos bajo su prefijo y rechazo de EMPLEADO. El servidor requiere nombre PRUEBA y confirmación expresa y limpia los archivos subidos si la transacción falla. Utiliza el límite específico MAX_REGISTROS_EVENTO_CHIAPAS cuando existe y el máximo SQL 500.

El panel de administración Chiapas incorpora Registrar prueba de Chiapas. El formulario se habilita solo en ese modo administrativo; el registro público Chiapas sigue cerrado. No se añade ese módulo al panel RADEV’S.

La suite completa pasó: lint, tipos, build, Deno, 236 comprobaciones de aislamiento, pruebas existentes, SQL/catalogo/etapas/rollback, 13 E2E con Chrome y backend simulado, y 21 sobre build estático con red externa bloqueada. Las pruebas multipart nuevas verifican prefijos Chiapas, evento RPC fijo, rechazo EMPLEADO y limpieza de archivos ante duplicado.

Se creó una cuenta Auth ficticia por acción del usuario en el panel; permanece sin perfil/asignación hasta completar las protecciones publicadas. Los IDs y el inventario para limpieza están en el respaldo .local, no en este documento. No se almacenó su contraseña.

Este commit prepara 24 bundles para publicación, excluyendo la ruta obsoleta registrar-participante. Los resultados reales posteriores deben registrarse por separado; estas pruebas no acreditan por sí solas el flujo completo en producción.
