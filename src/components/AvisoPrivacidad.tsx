import { useState } from "react";

type AvisoPrivacidadProps = {
  aceptado: boolean;
  onChange: (aceptado: boolean) => void;
};

// La versión identifica este texto, pero el backend actual debe revisarse
// para determinar si persiste la versión aceptada por cada participante.
export const PRIVACIDAD_VERSION = "2026-10-16-preparacion";

const correoPrivacidad = "joyeriamor@amor.com";

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
          <h4>Aviso de privacidad — Fiesta Anual AMOR 2026</h4>
          <p><strong>Fecha de revisión del texto:</strong> 16 de octubre de 2026.</p>

          <h4>1. Responsable y contacto</h4>
          <p>
            JOYERÍA AMOR DE LOS DOS, ubicada en Guadalajara, Jalisco, México,
            es responsable del tratamiento de los datos personales obtenidos
            mediante este formulario. Para asuntos de privacidad, escribe a{" "}
            <a href={`mailto:${correoPrivacidad}`}>{correoPrivacidad}</a>.
          </p>

          <h4>2. Datos recopilados</h4>
          <p>
            Nombre y apellidos, estado de residencia, WhatsApp, fotografía personal,
            asesor, tipo de participante cuando corresponda y grupo de ruta cuando
            aplique. En los registros de vendedoras también se solicita el
            comprobante de transferencia, que puede contener datos financieros.
            La plataforma genera un folio, invitación QR y registros del control de acceso.
            Se utilizan datos técnicos para proteger el formulario frente a usos indebidos.
          </p>

          <h4>3. Finalidades</h4>
          <p>
            Tramitar la inscripción, comunicarnos sobre el evento, revisar
            comprobantes o autorizar cortesías, identificar visualmente a la persona
            inscrita, emitir y verificar invitaciones, controlar ingresos y prevenir
            accesos duplicados o registros abusivos. La cortesía de promotoras y
            empleados está sujeta a autorización administrativa.
          </p>
          <p>
            No se solicita consentimiento para finalidades publicitarias mediante
            este registro. Si se quisieran usar los datos para un fin adicional,
            se informaría antes y se pediría el consentimiento que corresponda.
          </p>

          <h4>4. Comprobantes y consentimiento</h4>
          <p>
            Únicamente cuando adjuntes un comprobante bancario, el consentimiento
            expreso que se solicita abajo incluye el tratamiento de los datos
            financieros que puedan aparecer en él, exclusivamente para revisar y
            documentar el pago de inscripción.
          </p>

          <h4>5. Custodia, acceso y proveedores</h4>
          <p>
            La información se administra mediante la plataforma del evento.
            El personal autorizado accede a ella según su función, y pueden
            intervenir proveedores tecnológicos que prestan servicios de
            alojamiento, almacenamiento y seguridad. Las transferencias de
            datos a terceros independientes, si fueran necesarias, se informarán
            y se sujetarán a la legislación aplicable.
          </p>

          <h4>6. Conservación</h4>
          <p>
            Los datos se conservarán durante el tiempo necesario para la
            operación del evento, la atención de aclaraciones y el cumplimiento
            de obligaciones legales. Una vez agotadas las finalidades y los
            periodos legalmente aplicables, procederá su bloqueo o eliminación
            según corresponda. La política interna de conservación está pendiente
            de concretarse antes de la apertura pública.
          </p>

          <h4>7. Derechos ARCO y revocación</h4>
          <p>
            Puedes solicitar acceso, rectificación, cancelación u oposición al
            tratamiento de tus datos, limitar su uso o revocar tu consentimiento
            escribiendo a <a href={`mailto:${correoPrivacidad}`}>{correoPrivacidad}</a>.
            Indica tu nombre, un medio para responderte, el derecho que deseas
            ejercer y los datos relacionados con la solicitud. Para evitar que
            terceros obtengan tu información, podremos pedirte que acredites tu identidad.
          </p>
          <p>
            La determinación se comunicará en un plazo máximo de 20 días desde
            la recepción de la solicitud; si procede, se hará efectiva dentro
            de los 15 días siguientes a la comunicación, salvo los supuestos de
            ampliación legal. El ejercicio de estos derechos no tiene costo,
            sin perjuicio de los gastos permitidos por la normativa aplicable.
          </p>

          <h4>8. Cambios al aviso</h4>
          <p>
            Los cambios a este aviso se publicarán en la plataforma de
            inscripción de la Fiesta Anual AMOR 2026, donde podrá consultarse
            la versión actualizada.
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
