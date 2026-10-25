> Actualización posterior: Chiapas fue autorizado para apertura en SALÓN BLANCO. Consulta [la bitácora de apertura y pruebas](APERTURA_CHIAPAS_20261025.md) para el estado vigente. Este documento conserva el cierre de la fase anterior.

# Entrega final FIESTAANUAL26 — 25 de octubre de 2026

## Estado actual

Backend y frontend publicados. Código público: `43c51c558c5feaed2632476ed517320cff63ea5b`, rama `feature/chiapas-evento-2026`. GitHub Pages: ejecución #16, https://github.com/joyeriamor/evento-anual-amor-2026/actions/runs/40168327700. La excepción temporal de publicación se retiró; el entorno permite solamente `main`. No se hizo merge.

- RADEV’S: activo, 6 diciembre 2026, cupo 1500; se conserva su operación.
- Chiapas: borrador e inscripciones cerradas, 19 diciembre 2026, cupo 500, cuota $300 para participantes de pago. Cortesías sujetas a las reglas existentes.
- Administrador Chiapas: `hugo`, autorizado expresamente por el usuario. Solo se añadió su asignación a Chiapas. Perfil, contraseña y asignaciones de RADEV’S no cambiaron; la huella de las asignaciones RADEV’S antes y después fue `7b0ed56b38a6a9f6f9ac630075a4d683`.
- Inicio de sesión real de hugo en la página publicada: verificado. Panel Chiapas: 0 participantes, cupo 500 disponible; usuarios: únicamente hugo activo; participantes y bandejas del evento sin datos de RADEV’S.
- Ensayo previo eliminado: cero archivos, pagos, registros, invitaciones, accesos, secretos Vault, perfil, asignaciones, cuenta Auth y sesiones del ensayo.

## Funcionalidades entregadas

Selección de evento, inscripción y registro administrativo de ensayo, fotografía/comprobante privados, revisión de pagos, cortesías, cupos, invitaciones, recuperación/reemisión QR, consulta e ingreso por QR, control de duplicados, bandejas administrativas/personales y roles por evento. Veinticuatro Edge activas; JWT verificado contra Auth, perfil/rol/asignación activos y filtros de pertenencia antes de consultar relaciones o firmar archivos. Sin service_role en frontend.

## Pruebas y alcance

- Lint, tipos frontend/Edge y build: aprobados. Pruebas locales completas: 17/14/19 de módulos Chiapas, 236 aislamiento, 84 integración catalogada, 46+46 entrega por etapas, 13 E2E navegador con Supabase simulado y 21 hosting estático. Ver log respaldado; Auth/Storage/Vault de las pruebas locales son adaptadores, no servicios remotos.
- SQL real: 31 casos aislados pg_temp con ROLLBACK; pruebas adicionales de cortesía y asignación inactiva con claims SQL explícitos y ROLLBACK.
- HTTP real publicado: 20 endpoints privados sin sesión ->401; registro público Chiapas cerrado ->403. Con sesión ficticia válida: permisos Chiapas y denegaciones a RADEV’S, SELECT directo denegado y archivo privado existente sin firma denegado. Se conservan los resultados originales y la interpretación de dos expectativas HTTP incorrectas.
- Flujo real ficticio: alta con imágenes sintéticas, pago aprobado, QR Vault emitido, recuperación del mismo QR, reemisión y revocación anterior, QR Chiapas rechazado en RADEV’S, ingreso Chiapas y segundo ingreso rechazado. Limpieza final verificada.
- Publicación: tres rutas HTTP200; JavaScript/CSS idénticos byte por byte al candidato probado. Navegador real RADEV’S/Chiapas/acceso, registro público Chiapas rechazado403 y estados/cupos verificados por SQL.

## Límites y decisiones pendientes

No se afirma independencia de infraestructura: ambos eventos comparten Supabase y un artefacto GitHub Pages. No se realizó E2E con sesión real de un operador asignado únicamente a RADEV’S intentando operar Chiapas; ese sentido tiene pruebas locales/SQL. Hugo ya está autorizado en ambos y no es una cuenta adecuada para comprobar esa denegación. No se revocarán permisos reales ni se crearán cuentas adicionales sin indicación.

Antes de abrir Chiapas faltan definición de sede/horario, designación de otros operadores si se requieren y autorización expresa de apertura. No se inventaron esos datos ni se abrieron inscripciones. El administrador puede gestionar cuentas del evento desde su panel; no se crearon personas ni contraseñas reales por cuenta del usuario.

La rama main todavía no contiene la versión publicada. Un despliegue futuro debe incluir ambos eventos: publicar main antiguo reemplazaría el frontend actual. Su integración requiere autorización separada; no se cambió main ni el flujo para eludir esa decisión.

## Operación y recuperación

Inicio RADEV’S: https://joyeriamor.github.io/evento-anual-amor-2026/

Chiapas: https://joyeriamor.github.io/evento-anual-amor-2026/chiapas/

Acceso Chiapas: https://joyeriamor.github.io/evento-anual-amor-2026/chiapas/acceso/

Respaldos y evidencias sin credenciales en `RESPALDO_PUBLICACION_20261024.local`, excluido de Git. SQL aplicado por etapas y corrección incremental: ver manifiesto e historial registrados. No ejecutar db push desde la raíz: conserva una migración consolidada alternativa ya sustituida por la ruta aplicada. Los rollback estructurales no revierten operaciones de negocio posteriores; no borrar pagos/accesos reales como mecanismo de reversión. Documentación histórica: `PUBLICACION_BACKEND_20261024.md`; pruebas detalladas: `PRUEBAS_BACKEND_PUBLICADO_20261024.json`; publicación: `CIERRE_PUBLICACION_PAGES_20261025.json`.
