
import { useState } from "react";
import { supabase } from "../lib/supabase";

export default function PruebaParticipantes() {
  const [resultado, setResultado] = useState("");
  const [cargando, setCargando] = useState(false);

  async function probar() {
    setCargando(true);
    setResultado("");

    try {
      const { data, error: sesionError } =
        await supabase.auth.getSession();

      if (sesionError || !data.session) {
        setResultado(
          "No hay una sesión iniciada. Entra como administrador."
        );
        return;
      }

      const { data: respuesta, error } =
        await supabase.functions.invoke(
          "listar-participantes",
          {
            method: "POST",
            headers: {
              Authorization:
                `Bearer ${data.session.access_token}`,
            },
            body: {
              pagina: 1,
              limite: 20,
              busqueda: "",
            },
          }
        );

      if (error) {
        setResultado(
          JSON.stringify(
            {
              error: error.message,
              respuesta: respuesta,
            },
            null,
            2
          )
        );
        return;
      }

      setResultado(
        JSON.stringify(respuesta, null, 2)
      );
    } catch (error) {
      setResultado(
        error instanceof Error
          ? error.message
          : "Error desconocido"
      );
    } finally {
      setCargando(false);
    }
  }

  return (
    <section
      style={{
        padding: 24,
        background: "#fff",
        borderRadius: 16,
        marginTop: 24,
      }}
    >
      <h2>Prueba de participantes</h2>

      <p>
        Consulta segura utilizando tu sesión
        administrativa de Supabase.
      </p>

      <button
        type="button"
        onClick={probar}
        disabled={cargando}
        style={{
          padding: 14,
          background: "#a33460",
          color: "#fff",
          border: 0,
          borderRadius: 10,
          cursor: "pointer",
        }}
      >
        {cargando
          ? "Consultando..."
          : "Consultar participantes"}
      </button>

      {resultado && (
        <pre
          style={{
            marginTop: 20,
            padding: 16,
            background: "#f8f3f5",
            borderRadius: 10,
            overflowX: "auto",
            whiteSpace: "pre-wrap",
          }}
        >
          {resultado}
        </pre>
      )}
    </section>
  );
}
