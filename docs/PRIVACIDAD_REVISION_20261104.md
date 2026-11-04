# Página de privacidad preparada para revisión — 4 noviembre 2026

No publicada. No se cambió Supabase ni la configuración de WhatsApp durante este trabajo.
Ruta prevista: /evento-anual-amor-2026/privacidad/.
El texto completo existente se trasladó sin cambios a ContenidoAvisoPrivacidad.tsx y se comparte entre formulario y página pública. El correo existente se centralizó sin cambiar su valor.
El formulario conserva la aceptación obligatoria y la autorización independiente y opcional de WhatsApp. Los enlaces abren otra pestaña para no perder el formulario.
GitHub Pages recibe privacidad/index.html durante la compilación, sin depender de fallback SPA.

## Confirmaciones necesarias antes de publicar
- Nombre legal del responsable: JOYERÍA AMOR DE LOS DOS.
- Ubicación existente: Guadalajara, Jalisco, México; confirmar si es la oficial y si debe ampliarse.
- Correo existente: joyeriamor@amor.com; confirmar que es oficial y está atendido.
- Versión existente: 2026-10-16-preparacion y revisión del texto 16 octubre 2026; no se actualizaron como si existiera aprobación nueva.
- Conservación: el apartado 6 todavía dice que la política interna está pendiente de concretarse antes de la apertura pública. El responsable debe definir el criterio o periodo real y aprobar el texto que lo sustituya; no se inventó ninguno.

No utilizar esta página como política definitiva en Meta ni publicarla hasta que el usuario confirme el contenido.

## Validación local
- Lint y compilación aprobados; permanece la advertencia previa de bundle mayor de 500 kB.
- 45 comprobaciones de privacidad aprobadas con HTTP estático y navegador reales: ruta directa, recarga, página anónima sin consultas al backend, ocho apartados, vista móvil sin desbordamiento, contenido igual al del formulario y conservación de datos al abrir otra pestaña.
- En ambos eventos se verificaron las casillas independientes: privacidad obligatoria y WhatsApp opcional. No se enviaron formularios a producción.
- 27 comprobaciones E2E de regresión aprobadas, con Supabase HTTP simulado. No son pruebas reales de Auth/Storage/Meta.
- Se corrigió un selector del propio ensayo tras su primera ejecución; no se cambió el formulario para satisfacerlo.
- Registro.tsx y las funciones/configuración de WhatsApp no se modificaron. No se consultaron ni escribieron datos de producción durante esta tarea.
- La vista previa se compiló con credenciales ficticias y se sirve localmente; no se desplegó ni se guardó la URL en Meta.
