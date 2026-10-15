
import { useState } from "react";

type AvisoPrivacidadProps = {
  aceptado: boolean;
  onChange: (aceptado: boolean) => void;
};

export const PRIVACIDAD_VERSION = "borrador-2026-10";

export default function AvisoPrivacidad({
  aceptado,
  onChange,
}: AvisoPrivacidadProps) {
  const [abierto, setAbierto] = useState(false);

  return (
    <section
      style={{
        border: "1px solid #efcbd8",
        borderRadius: 16,
        padding: 20,
        background: "#fff9fb",
        marginTop: 24,
      }}
    >
      <h3 style={{ marginTop: 0, color: "#9b3159" }}>
        🔒 Privacidad y protección de datos
      </h3>

      <p style={{ lineHeight: 1.6 }}>
        Joyería AMOR utilizará tus datos para
        gestionar tu inscripción a la Fiesta
        Anual AMOR 2026, revisar tu comprobante
        de pago y controlar el acceso al evento.
      </p>

      <button
        type="button"
        onClick={() => setAbierto(!abierto)}
        aria-expanded={abierto}
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
        {abierto
          ? "Ocultar aviso de privacidad"
          : "Leer aviso de privacidad"}
      </button>

      {abierto && (
        <div
          style={{
            background: "#ffffff",
            border: "1px solid #f1d8e1",
            borderRadius: 12,
            padding: 16,
            marginTop: 12,
            maxHeight: 320,
            overflowY: "auto",
            lineHeight: 1.7,
          }}
        >
          <h4>Aviso de privacidad — Borrador</h4>

          <p>
            <strong>Organizador:</strong> Joyería AMOR.
          </p>

          <p>
            <strong>Datos recopilados:</strong> nombres,
            apellidos, estado de residencia, número
            de WhatsApp, fotografía y comprobante
            de pago.
          </p>

          <p>
            <strong>Finalidades:</strong> administrar
            inscripciones, identificar participantes,
            revisar pagos, emitir invitaciones y
            controlar el acceso al evento.
          </p>

          <p>
            <strong>Protección:</strong> la información
            será almacenada en sistemas con acceso
            restringido al personal autorizado.
          </p>

          <p>
            <strong>Derechos ARCO:</strong> el aviso
            definitivo indicará cómo solicitar acceso,
            rectificación, cancelación u oposición
            al tratamiento de datos personales.
          </p>

          <p>
            <strong>Pendiente antes de publicación:</strong>
            identificación del responsable legal,
            domicilio, medio de contacto, conservación
            de datos y transferencias aplicables.
          </p>
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
        />

        <span>
          He leído y acepto el aviso de privacidad.
        </span>
      </label>

      <p
        style={{
          fontSize: 12,
          color: "#856b75",
          marginBottom: 0,
        }}
      >
        Aviso en preparación. Las inscripciones
        públicas todavía no están habilitadas.
      </p>
    </section>
  );
}
