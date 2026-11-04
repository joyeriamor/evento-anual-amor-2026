import { useState } from "react";
import ContenidoAvisoPrivacidad from "./ContenidoAvisoPrivacidad";
import { correoPrivacidad } from "../config/privacidad";

type AvisoPrivacidadProps = {
  aceptado: boolean;
  onChange: (aceptado: boolean) => void;
};

// La versión identifica este texto, pero el backend actual debe revisarse
// para determinar si persiste la versión aceptada por cada participante.
export const PRIVACIDAD_VERSION = "2026-10-16-preparacion";

export default function AvisoPrivacidad({
  aceptado,
  onChange,
}: AvisoPrivacidadProps) {
  const [abierto, setAbierto] = useState(false);

  return (
    <section
      aria-labelledby="titulo-privacidad-amor"
      style={{
        border: "1px solid #efcbd8",
        borderRadius: 16,
        padding: 20,
        background: "#fff9fb",
        marginTop: 24,
      }}
    >
      <h3 id="titulo-privacidad-amor" style={{ marginTop: 0, color: "#9b3159" }}>
        Privacidad y protección de datos
      </h3>

      <p style={{ lineHeight: 1.6 }}>
        JOYERÍA AMOR DE LOS DOS utilizará la información que proporciones para
        registrar tu participación en la Fiesta Anual AMOR 2026, revisar pagos
        o solicitudes de cortesía, emitir invitaciones y controlar el acceso al evento.
        Solo las vendedoras deberán adjuntar comprobante de pago.
      </p>

      <p style={{ lineHeight: 1.6 }}>
        <strong>Responsable:</strong> JOYERÍA AMOR DE LOS DOS. <strong>Ubicación:</strong>{" "}
        Guadalajara, Jalisco, México. <strong>Contacto de privacidad:</strong>{" "}
        <a href={`mailto:${correoPrivacidad}`}>{correoPrivacidad}</a>.
      </p>

      <button
        type="button"
        onClick={() => setAbierto((actual) => !actual)}
        aria-expanded={abierto}
        aria-controls="contenido-aviso-privacidad-amor"
        style={{
          background: "transparent",
          color: "#9b3159",
          border: "none",
          textDecoration: "underline",
          cursor: "pointer",
          padding: "8px 0",
          fontWeight: 600,
        }}
      >
        {abierto ? "Ocultar aviso de privacidad" : "Leer aviso de privacidad completo"}
      </button>

      <p>
        <a href={`${import.meta.env.BASE_URL}privacidad/`} target="_blank" rel="noopener noreferrer">
          Abrir aviso de privacidad en una página independiente
        </a>
      </p>

      {abierto && (
        <div
          id="contenido-aviso-privacidad-amor"
          style={{
            background: "#ffffff",
            border: "1px solid #f1d8e1",
            borderRadius: 12,
            padding: 16,
            marginTop: 12,
            maxHeight: 420,
            overflowY: "auto",
            lineHeight: 1.7,
          }}
        >
          <ContenidoAvisoPrivacidad />
        </div>
      )}

      <label
        style={{
          display: "flex",
          gap: 10,
          alignItems: "flex-start",
          marginTop: 18,
          cursor: "pointer",
        }}
      >
        <input
          type="checkbox"
          checked={aceptado}
          onChange={(e) => onChange(e.target.checked)}
          style={{ marginTop: 4 }}
          required
        />
        <span>
          He leído el aviso de privacidad y autorizo el tratamiento de mis datos
          para el registro al evento. Si adjunto un comprobante bancario, también
          autorizo expresamente el tratamiento de los datos financieros que contenga
          exclusivamente para revisar mi pago.
        </span>
      </label>
      <p style={{ fontSize: 12, color: "#856b75", marginBottom: 0 }}>
        La aceptación es necesaria para continuar con el registro.
      </p>
    </section>
  );
}
