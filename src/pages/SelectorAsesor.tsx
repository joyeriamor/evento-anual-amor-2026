import { useEffect, useState } from "react";

type Asesor = {
  id: string;
  nombre: string;
};

type Respuesta = {
  ok?: boolean;
  asesores?: Asesor[];
  mensaje?: string;
  error?: string;
};

/**
 * Lista pública de asesores. Consulta el endpoint público de solo lectura,
 * sin añadir la sesión ni encabezados de autenticación del administrador.
 * Nunca se utiliza una clave service_role en el navegador.
 */
export default function SelectorAsesor({
  onChange,
}: {
  onChange?: (asesor: Asesor | null) => void;
}) {
  const [asesores, setAsesores] = useState<Asesor[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState("");
  const [intento, setIntento] = useState(0);

  useEffect(() => {
    const control = new AbortController();
    let montado = true;
    let agotoTiempo = false;
    const temporizador = window.setTimeout(() => {
      agotoTiempo = true;
      control.abort();
    }, 15000);

    async function cargar() {
      setCargando(true);
      setError("");
      try {
        const base = import.meta.env.VITE_SUPABASE_URL?.replace(/\/+$/, "");
        if (!base) throw new Error("Falta VITE_SUPABASE_URL en .env.local.");

        const respuesta = await fetch(`${base}/functions/v1/listar-asesores-registro`, {
          method: "POST",
          mode: "cors",
          headers: { "Content-Type": "application/json" },
          body: "{}",
          credentials: "omit",
          signal: control.signal,
        });

        let datos: Respuesta;
        try {
          datos = (await respuesta.json()) as Respuesta;
        } catch {
          throw new Error(`El servidor respondió HTTP ${respuesta.status} sin JSON válido.`);
        }

        if (!respuesta.ok || datos.ok !== true || !Array.isArray(datos.asesores)) {
          throw new Error(datos.mensaje ?? datos.error ?? `Error HTTP ${respuesta.status} al consultar asesores.`);
        }

        if (!control.signal.aborted) setAsesores(datos.asesores);
      } catch (fallo) {
        if (!montado) return;
        const detalle = agotoTiempo
          ? "La solicitud agotó los 15 segundos de espera."
          : fallo instanceof Error ? fallo.message : String(fallo);
        console.error("No se pudieron cargar asesores desde listar-asesores-registro:", fallo);
        setError(
          detalle === "Failed to fetch"
            ? "El navegador bloqueó la consulta. Abre F12 → Red y revisa listar-asesores-registro."
            : detalle === "This operation was aborted" || detalle.includes("aborted")
              ? "La solicitud agotó los 15 segundos de espera."
              : detalle
        );
      } finally {
        window.clearTimeout(temporizador);
        if (montado) setCargando(false);
      }
    }

    void cargar();
    return () => {
      window.clearTimeout(temporizador);
      montado = false;
      control.abort();
    };
  }, [intento]);

  return (
    <label>
      Asesor *
      <select
        name="asesor"
        required
        defaultValue=""
        onChange={(evento) => {
          const asesor = asesores.find((a) => a.id === evento.target.value) ?? null;
          onChange?.(asesor);
        }}
        disabled={cargando || !!error || asesores.length === 0}
      >
        <option value="" disabled>
          {cargando
            ? "Cargando asesores..."
            : error
              ? "Error al cargar asesores"
              : asesores.length === 0
                ? "No hay asesores disponibles"
                : "Selecciona tu asesor"}
        </option>
        {asesores.map((asesor) => (
          <option key={asesor.id} value={asesor.id}>
            {asesor.nombre}
          </option>
        ))}
      </select>
      {error && (
        <span style={{ display: "block", marginTop: 6 }}>
          <small role="alert" style={{ color: "#b91c1c" }}>{error}</small>{" "}
          <button
            type="button"
            onClick={() => setIntento((anterior) => anterior + 1)}
            style={{ border: "1px solid #a33460", color: "#a33460", background: "#fff", borderRadius: 6, padding: "5px 8px", cursor: "pointer" }}
          >
            Reintentar
          </button>
        </span>
      )}
    </label>
  );
}
