import { correoPrivacidad } from "../config/privacidad";

/** Contenido único compartido por el formulario y la página pública. */
export default function ContenidoAvisoPrivacidad() {
  return (
    <>
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
    </>
  );
}
