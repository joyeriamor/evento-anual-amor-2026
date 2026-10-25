# Corrección local de rutas para publicación estática

24 de octubre de 2026. Continuación de `6c2ee82`, sin cuentas nuevas, despliegue o cambios de producción.

## Problema encontrado

El workflow existente publica `dist` en GitHub Pages. La aplicación identifica el evento y el control de acceso por el pathname, y los enlaces apuntan a `/evento-anual-amor-2026/chiapas` y `/evento-anual-amor-2026/chiapas/acceso`. La compilación anterior solo generaba `index.html` en la raíz. Vite dev resolvía esos enlaces con su fallback de SPA, ocultando que un servidor estático sin fallback no tenía archivos HTML para esas rutas.

No se declaró una caída observada en el sitio publicado: se identificó la incompatibilidad en el código/build local y se probó con un servidor de archivos, sin consultar participantes o utilizar el sitio real.

## Cambio

El plugin de compilación en `vite.config.ts` genera dos copias del entrypoint construido:

- `dist/chiapas/index.html`
- `dist/chiapas/acceso/index.html`

Los scripts, estilos y recursos usan el mismo prefijo absoluto de Vite, por lo que funcionan también en las rutas anidadas. No se cambia el identificador del evento, los permisos, los estados de inscripción, la sesión o el flujo RADEV’S. No se publica un 404 global ni se ocultan otras rutas inexistentes. El favicon usa `%BASE_URL%` y el idioma HTML pasa a español.

El archivo `.github/workflows/deploy.yml` modificado por el usuario se inspeccionó, pero no se editó ni ejecutó. Tampoco se modificaron sus variables o credenciales. El workflow continúa publicando solo con sus disparadores configurados; esta entrega no lo dispara.

## Verificación

`test-pages-estatico.cjs` sirve el contenido real de `dist` en localhost sin fallback de SPA. Las carpetas se redirigen a su forma con barra final y una ruta inexistente devuelve 404. La prueba usa Chrome real para navegar y recargar Chiapas y su acceso directo, comprobar que se mantiene el cierre de inscripción y validar el favicon bajo el prefijo correcto.

Toda solicitud del navegador a otro origen se aborta. No se inicia sesión, se crean cuentas o se invocan los servicios reales Supabase. El escaneo del build rechaza archivos de entorno, respaldos, SQL, claves, logs y mapas y busca formatos detectables de secretos/JWT service_role. Ese escaneo es una protección limitada; no certifica la ausencia absoluta de secretos codificados de otras formas.

La primera ejecución de esta prueba detectó que la copia temporal del repositorio no contenía `.env.local`: la compilación anterior terminaba correctamente, pero al ejecutarse lanzaba el error de configuración de Supabase. No se interpretó como una falla de Auth real. La suite ahora compila explícitamente con URL y clave ficticias, y prueba ese artefacto con red externa bloqueada.

**El `dist` generado por `test:local` es un artefacto de pruebas y NO se debe publicar.** Una futura entrega debe reconstruirse con las variables públicas aprobadas en el entorno real de compilación. El workflow ya proporciona variables públicas; no se cambió. Las credenciales privadas nunca se incluyen en el frontend.

Para verificar después de una compilación local con configuración pública válida o ficticia:

```
node scripts/test-pages-estatico.cjs
```

`FIESTA_CHROME_PATH` puede indicar un Chrome instalado; si se omite, Playwright necesita tener su Chromium instalado. `scripts/verificar-local.cjs` ejecuta esta prueba después del build y las comprobaciones previas, siempre con configuración ficticia para su build de prueba.

## Alcance pendiente

La corrección está preparada solo en la rama local. No habilita Chiapas ni sustituye las dependencias SQL/Edge y sus aprobaciones. Las pruebas positivas con cuentas, archivos existentes y QR de extremo a extremo siguen pendientes conforme a la decisión de continuar sin cuentas. El usuario pidió dejar intacto el perfil sin asignación; no se modificó.

## Resultado final

La suite completa finalizó con código 0. Las nuevas pruebas estáticas aprobaron 21 comprobaciones; la prueba de regresión sobre una copia temporal sin las entradas Chiapas falló como se esperaba con `Falta HTML físico: chiapas/`. El frontend anterior en Vite mantuvo sus 10 comprobaciones aprobadas. Se conservan aprobados lint, tipos, build, Edge, autorización y SQL según la evidencia `RESULTADO_PAGES_ESTATICO_20261024.json`. No se repitieron sondas a servicios de producción en esta continuación.
