import { useEffect, useState } from "react";
import { invocarEvento } from "../lib/evento";

type Persona = {
  nombres: string | null;
  apellidos: string | null;
  estado_residencia: string | null;
  tipo_participante: string | null;
};

type Fila = {
  id: string;
  grupo_ruta: string | null;
  promotora: Persona | Persona[] | null;
};

type Respuesta = { ok: boolean; total: number; filas: Fila[] };
const LIMITE = 50;

const persona = (fila: Fila) =>
  Array.isArray(fila.promotora) ? fila.promotora[0] : fila.promotora;

export default function ReporteAsesor({ asesorId }: { asesorId: string }) {
  const [filas, setFilas] = useState<Fila[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let vigente = true;

    async function consultar() {
      const registros = new Map<string, Fila>();
      let total = 0;
      try {
        for (let pagina = 1; vigente; pagina += 1) {
          const { data, error: fallo } = await invocarEvento("listar-participantes", {
            body: { reporte_asesor: true, asesor_id: asesorId, pagina, limite: LIMITE },
          });
          const respuesta = data as Respuesta | null;
          if (!vigente) return;
          if (fallo || !respuesta?.ok || !Array.isArray(respuesta.filas) ||
              !Number.isSafeInteger(respuesta.total) || respuesta.total < 0) {
            throw new Error("No se pudo cargar el reporte del asesor. Pulsa Actualizar para intentar de nuevo.");
          }
          if (pagina === 1) total = respuesta.total;
          if (respuesta.total !== total) break;
          for (const fila of respuesta.filas) registros.set(fila.id, fila);
          if (pagina * LIMITE >= total || respuesta.filas.length < LIMITE) {
            if (registros.size !== total) break;
            setFilas([...registros.values()]);
            return;
          }
        }
        if (vigente) setError("La lista cambió mientras se cargaba. Pulsa Actualizar para obtener el reporte completo.");
      } catch (fallo) {
        if (vigente) setError(fallo instanceof Error ? fallo.message : "No se pudo cargar el reporte.");
      }
    }

    void consultar();
    return () => { vigente = false; };
  }, [asesorId]);

  if (error) return <p role="alert">{error}</p>;
  if (!filas) return <p role="status">Consultando inscripciones del asesor…</p>;

  const promotoras = filas.filter((fila) => persona(fila)?.tipo_participante === "promotora").length;
  const vendedoras = filas.filter((fila) => persona(fila)?.tipo_participante === "vendedora").length;
  const sinTipo = filas.length - promotoras - vendedoras;

  async function exportar() {
    if (!filas?.length) return;
    try {
      const { descargarReporteAsesor } = await import("../lib/exportarReporteAsesor");
      descargarReporteAsesor(filas.map((fila) => {
        const datos = persona(fila);
        return [
          [datos?.nombres, datos?.apellidos].filter(Boolean).join(" "),
          datos?.estado_residencia ?? "",
          fila.grupo_ruta ?? "",
        ];
      }));
    } catch {
      setError("No se pudo generar el archivo. Pulsa Actualizar para intentar de nuevo.");
    }
  }

  return (
    <div aria-label="Resumen del asesor" style={{ display: "flex", flexWrap: "wrap", gap: 14, alignItems: "center", marginBottom: 20 }}>
      <span>Promotoras <strong>{promotoras}</strong></span>
      <span>Vendedoras <strong>{vendedoras}</strong></span>
      {sinTipo > 0 && <span>Sin tipo registrado <strong>{sinTipo}</strong></span>}
      <button type="button" disabled={!filas.length} onClick={() => void exportar()}>
        Exportar asesor a Excel
      </button>
    </div>
  );
}
