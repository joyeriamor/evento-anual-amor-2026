# Filtro de envío manual en Invitaciones QR

El selector «Todos los envíos / Por enviar / Enviadas» se combina con
«Todas las invitaciones / Emitidas» y la búsqueda existente. El total y la
paginación se calculan en PostgreSQL después de aplicar los filtros.

«Por enviar» incluye invitaciones emitidas o activas cuya marca manual es
falsa o nula. «Enviadas» incluye las marcadas manualmente. No se envían mensajes.
Las invitaciones sin emitir o revocadas quedan fuera de ambos filtros de envío.
El orden sigue siendo la emisión más reciente primero.

Al cambiar la marca manual, se actualizan la lista y el total filtrados.
Si desaparece la última fila de una página, el panel vuelve a la última
página válida.

## Publicación (requiere autorización de producción)

1. Aplicar únicamente
   `supabase/migrations/20261125155422_filtro_envio_manual_invitaciones.sql`.
   Agrega sobrecargas de cinco argumentos; conserva las RPC de cuatro argumentos.
   No modifica datos.
2. Actualizar `bandejas-admin` y `bandejas-admin-chiapas`.
   Ambas validan el filtro y pasan la identidad del JWT verificado a su RPC.
3. Publicar el frontend desde `feature/chiapas-evento-2026`, sin merge a main.
4. Verificar en el panel que «Emitidas + Enviadas» y «Emitidas + Por enviar»
   sumen el total de emitidas. No cambiar marcas reales durante esta revisión.

Para revertir: restaurar primero frontend y Edge a la versión anterior;
después ejecutar
`supabase/rollbacks/20261125155422_filtro_envio_manual_invitaciones.sql`.
El rollback elimina solo las nuevas sobrecargas.

## Validación local

- Compilación TypeScript y Vite, lint.
- `node tests/chiapas/filtro-envio-manual.integration.mjs`: SQL local PGlite
  con datos ficticios de ambos eventos; combina filtros, búsqueda, totales,
  paginación, marcas falsas/nulas, orden, permisos, aislamiento y rollback.
- `node tests/chiapas/bandejas-admin-chiapas-http.test.cjs`: handlers con
  Auth/RPC simulados; valida 21 casos, incluidos filtros y entrada inválida.
- `node tests/chiapas/aislamiento-eventos.test.cjs`: 252 comprobaciones con
  transporte HTTP local y Supabase simulado.

Estas pruebas no acreditan una publicación ni una sesión real de producción.
