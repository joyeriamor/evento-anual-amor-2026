import react from '@vitejs/plugin-react'
import { defineConfig, type Plugin } from 'vite'

// GitHub Pages serves files, without Vite's development SPA fallback.
// Emit explicit entrypoints so direct links/QR routes work on static hosting.
function paginasEventos(): Plugin {
  return {
    name: 'paginas-estaticas-eventos',
    apply: 'build',
    enforce: 'post',
    generateBundle: {
      order: 'post',
      handler(_options, bundle) {
        const inicio = bundle['index.html']
        if (!inicio || inicio.type !== 'asset') {
          this.error('Falta index.html para generar las rutas estáticas de Chiapas')
        }
        for (const ruta of ['chiapas', 'chiapas/acceso']) {
          this.emitFile({ type: 'asset', fileName: `${ruta}/index.html`, source: inicio.source })
        }
      },
    },
  }
}

export default defineConfig({
  plugins: [react(), paginasEventos()],
  base: '/evento-anual-amor-2026/',
})
