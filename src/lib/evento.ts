import { supabase } from './supabase';
import { EVENTOS as CONFIGURACION } from '../config/eventos';

export const EVENTOS = {
  radevs: { id: CONFIGURACION.minatitlan.id, nombre: "RADEV'S · Minatitlán", fecha: '6 de diciembre de 2026', capacidad: CONFIGURACION.minatitlan.cupo },
  chiapas: { id: CONFIGURACION.chiapas.id, nombre: 'Fiesta Anual AMOR · Chiapas', fecha: '19 de diciembre de 2026', capacidad: CONFIGURACION.chiapas.cupo },
} as const;
export const esChiapas = /(?:^|\/)chiapas(?:\/|$)/.test(window.location.pathname);
export const eventoActual = esChiapas ? EVENTOS.chiapas : EVENTOS.radevs;
const independientes = new Set(['validar-pago', 'administrar-invitacion', 'bandejas-admin', 'bandeja-personal']);

/** Routing is a UI convenience. Every endpoint independently authorizes the event. */
export function invocarEvento(nombre: string, opciones: Parameters<typeof supabase.functions.invoke>[1] = {}) {
  const funcion = esChiapas && independientes.has(nombre) ? `${nombre}-chiapas` : nombre;
  return supabase.functions.invoke(funcion, {
    ...opciones,
    body: { ...(opciones.body as Record<string, unknown> || {}), evento_id: eventoActual.id },
  });
}
