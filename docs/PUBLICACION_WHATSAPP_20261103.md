# Publicacion WhatsApp — 3 noviembre 2026

Publicado el codigo ae1b380 en feature/chiapas-evento-2026, sin merge a main.
GitHub Pages: https://github.com/joyeriamor/evento-anual-amor-2026/actions/runs/41751428709 (exito).
Panel visible y consulta administrativa real verificada con la sesion de hugo en Chiapas; respuesta sin errores y sin inscripciones confirmadas en la pagina.

## Produccion
Migracion whatsapp_automatizacion_envios_apagados, version remota 20261104005405; archivo local 20261104002122_whatsapp_automatizacion.sql. No ejecutar nuevamente por diferencia de timestamp.
Funciones activas: whatsapp-procesar-cola v1, whatsapp-webhook v1, whatsapp-administrar v1, whatsapp-preparar-invitacion v4, whatsapp-generar-qr-png v3, whatsapp-generar-invitacion-png v3, registrar-participante-chiapas v10.
RADEV registrar-participante-v2 no fue publicado nuevamente.
SDK fijado a npm:@supabase/supabase-js@2.117.3 tras error del empaquetador con esm.sh. Dependencias congeladas con whatsapp-edge.lock.
Variable publica VITE_WHATSAPP_PANEL_HABILITADO=true.
Excepcion de feature retirada de github-pages; solo main permanece autorizado. Otras protecciones conservadas.

## Envios apagados
WHATSAPP_MODO=simulacion. ENVIOS_HABILITADOS, PRODUCCION_AUTORIZADA, WEBHOOK_HABILITADO, LIMPIEZA_HABILITADA, PLANTILLA_APROBADA, NUMERO_CONFIGURADO, CREDENCIAL_PERMANENTE y PRUEBA_MANUAL_AUTORIZADA (prefijo WHATSAPP_) estan en false.
No se configuro worker secret ni credencial permanente de Meta. No se creo cron ni se enviaron mensajes.
La funcion manual preexistente whatsapp-prueba no fue invocada ni modificada; estos interruptores corresponden a la automatizacion nueva.

## Verificacion
HTTP real sin autorizacion: worker 401, webhook 503, administrar/preparar/PNG QR/PNG invitacion 401; registro publico Chiapas y RADEV con cuerpo vacio 415. Sin altas ni archivos de ensayo.
Auth real: inicio de sesion por el usuario y lectura del panel publicado correctos.
Vault real: comparacion interna SHA256 de 8 tokens existentes de RADEV correcta, sin extraer tokens. No equivale a emitir un QR nuevo de Chiapas.
Funciones originales de pagos/cortesias/emision/registro v4 mantienen huella 9f29c8543b6316e12b0f0d703ee79f0b.
RADEV conserva 143 registros y huella 6e8bc23ce40a6ceae2cf0d66a5f6f2ba.
Chiapas paso de 26 a 27 registros durante la ventana; esta tarea no realizo altas. No se alteraron ni eliminaron esos registros.
RLS de inbox verificado y ningun RPC nuevo concedido a anon/authenticated.
Pruebas locales y limites detallados en WHATSAPP_AUTOMATIZACION_LOCAL_20261103.md: 22 motor, 48 HTTP registro, 24 HTTP worker, 97 PGlite, 104 PostgreSQL, 252 aislamiento, pruebas existentes, navegador, lint y build. Meta/backend fueron simulados en pruebas locales; no afirmar entrega real.

## Pendiente para activar
Esperar aprobacion de amor_invitacion_confirmada_v1 por Meta; configurar numero y credencial permanente mediante canal seguro; autorizar una prueba manual con destinatario consentido y verificar webhook/entrega reales. Activacion y programacion requieren autorizacion nueva.
Respaldos originales y rollback se conservaron en RESPALDO_PUBLICACION_20261024.local/whatsapp-publicacion-20261103 (ignorado). No aplicar rollback completo sin revisar trabajos o consentimientos nuevos.
