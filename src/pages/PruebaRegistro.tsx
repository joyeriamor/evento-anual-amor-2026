
import { useState, type FormEvent } from "react";
import { supabase } from "../lib/supabase";

export default function PruebaRegistro() {
  const [mensaje, setMensaje] = useState("");
  const [enviando, setEnviando] = useState(false);

  async function probar(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const formulario = event.currentTarget;
    const datos = new FormData(formulario);

    setEnviando(true);
    setMensaje("Enviando prueba al servidor...");

    try {
      const { data, error } = await supabase.functions.invoke(
        "registrar-participante",
        {
          body: datos,
        }
      );

      if (error) {
        const respuesta = await error.context?.json?.().catch(
          () => null
        );

        setMensaje(
          respuesta?.mensaje ??
          error.message ??
          "No se pudo conectar con el servidor."
        );
        return;
      }

      setMensaje(
        JSON.stringify(data, null, 2)
      );
    } catch (error) {
      setMensaje(
        error instanceof Error
          ? error.message
          : "Error desconocido"
      );
    } finally {
      setEnviando(false);
    }
  }

  return (
    <main
      style={{
        maxWidth: 550,
        margin: "35px auto",
        padding: 20,
        fontFamily: "Arial, sans-serif",
      }}
    >
      <h1>Prueba de registro AMOR</h1>

      <p>
        Esta pantalla solamente valida la comunicación
        con Supabase. No guarda inscripciones.
      </p>

      <form
        onSubmit={probar}
        style={{ display: "grid", gap: 15 }}
      >
        <label>
          Nombres
          <input
            name="nombres"
            required
            minLength={2}
            placeholder="Nombre de prueba"
          />
        </label>

        <label>
          Apellidos
          <input
            name="apellidos"
            required
            minLength={2}
            placeholder="Apellido de prueba"
          />
        </label>

        <label>
          WhatsApp
          <input
            name="whatsapp"
            required
            pattern="[0-9]{10}"
            placeholder="1234567890"
          />
        </label>

        <label>
          Estado
          <input
            name="estado"
            required
            defaultValue="Veracruz"
          />
        </label>

        <label>
          Asesor
          <select name="asesor_id" required defaultValue="">
            <option value="" disabled>
              Selecciona un asesor
            </option>
            <option value="00000000-0000-4000-8000-000000000001">
              Asesor de prueba
            </option>
          </select>
        </label>

        <label>
          Selfie de prueba
          <input
            name="foto"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            required
          />
        </label>

        <label>
          Comprobante de prueba
          <input
            name="comprobante"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            required
          />
        </label>

        <button type="submit" disabled={enviando}>
          {enviando ? "Enviando..." : "Probar conexión"}
        </button>
      </form>

      {mensaje && (
        <pre
          style={{
            marginTop: 20,
            padding: 15,
            background: "#f5f5f5",
            borderRadius: 10,
            whiteSpace: "pre-wrap",
            overflowWrap: "anywhere",
          }}
        >
          {mensaje}
        </pre>
      )}
    </main>
  );
}
