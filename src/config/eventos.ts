export const EVENTOS = {
  minatitlan: {
    id: "43e67bda-d19d-4c0e-a639-e85f2d62f294",
    clave: "minatitlan",
    nombre: "Fiesta Anual AMOR 2026",
    ciudad: "Minatitlán, Veracruz",
    sede: "Salón RADEV'S 1",
    fecha: "2026-12-06",
    cupo: 1500,
    cuotaVendedora: 300,
    permiteEmpleados: true,
    permitePromotoras: true,
    permiteVendedoras: true,
  },

  chiapas: {
    id: "3dc92160-79af-4bf7-b770-263038e88900",
    clave: "chiapas",
    nombre: "Fiesta Anual AMOR 2026 - Chiapas",
    ciudad: "Tuxtla Gutiérrez, Chiapas",
    sede: "SALÓN BIANCO",
    horario: "Horario por confirmar",
    inscripcionesHabilitadas: true,
    fecha: "2026-12-19",
    cupo: 500,
    cuotaVendedora: 300,
    permiteEmpleados: false,
    permitePromotoras: true,
    permiteVendedoras: true,
  },
} as const;

export type ClaveEvento = keyof typeof EVENTOS;

export function obtenerEvento(
  clave: string
) {
  if (clave === "chiapas") {
    return EVENTOS.chiapas;
  }

  return EVENTOS.minatitlan;
}