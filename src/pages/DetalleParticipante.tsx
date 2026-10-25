import { esChiapas, eventoActual } from '../lib/evento';
import { invocarEvento } from '../lib/evento';

import { useCallback, useEffect, useState } from "react";
import type { CSSProperties } from "react";
import {
  X,
  UserRound,
  Receipt,
  RefreshCw,
  ShieldCheck,
  CheckCircle2,
  XCircle,
  Gift,
  QrCode,
  Printer,
  Download,
  MessageCircle,
} from "lucide-react";
import { supabase } from "../lib/supabase";
import { QRCodeSVG } from "qrcode.react";
type Props = {
  registroId: string;
  onCerrar: () => void;
  onPagoActualizado?: () => void;
};
type Pago = {
  id: string;
  importe: number | null;
  referencia: string | null;
  estado: string | null;
  cuenta_destino: string | null;
  validado_at: string | null;
  created_at: string | null;
  comprobante_url: string | null;
};
type Participante = {
  id: string;
  folio: string | null;
  estado: string | null;
  exento_pago: boolean;
  created_at: string | null;
  promotora: {
    nombres: string;
    apellidos: string;
    telefono_whatsapp: string;
    estado_residencia: string;
    foto_url: string | null;
  } | null;
  asesor: {
    nombre: string;
  } | null;
  evento: {
    nombre: string;
  } | null;
  pagos: Pago[];
};
type InvitacionQR = { token: string; registroId: string };

// Las imágenes de la invitación se cargan desde el mismo sitio; nunca enviamos el QR a terceros.
function cargarImagenLocal(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const imagen = new Image();
    imagen.onload = () => resolve(imagen);
    imagen.onerror = () => reject(new Error(`No se pudo cargar el recurso visual: ${url}`));
    imagen.src = url;
  });
}


function extraerToken(resultado: unknown): string | null {
  if (!resultado || typeof resultado !== "object") return null;
  const r = resultado as Record<string, unknown>;
  const invitacion = r.invitacion;
  if (invitacion && typeof invitacion === "object") {
    const token = (invitacion as Record<string, unknown>).token_qr;
    if (typeof token === "string" && token.length > 0) return token;
  }
  if (typeof r.token_qr === "string" && r.token_qr.length > 0) return r.token_qr;
  if (r.resultado) return extraerToken(r.resultado);
  return null;
}

async function mensajeErrorFuncion(errorFuncion: { message: string; context?: unknown }): Promise<string> {
  const contexto = errorFuncion.context;
  if (contexto instanceof Response) {
    try {
      const json = await contexto.clone().json();
      return json?.error ?? json?.mensaje ?? errorFuncion.message;
    } catch { /* Conservamos el error original. */ }
  }
  return errorFuncion.message;
}

function fecha(valor: string | null) {
  if (!valor) return "—";
  const d = new Date(valor);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleString("es-MX", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "America/Mexico_City",
  });
}
function dinero(valor: number | null) {
  if (valor === null) return "—";
  return new Intl.NumberFormat("es-MX", {
    style: "currency",
    currency: "MXN",
  }).format(valor);
}
const tarjeta: CSSProperties = {
  padding: 18,
  border: "1px solid #f0d5df",
  borderRadius: 12,
  background: "#fff",
};
const botonBase: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 8,
  border: "none",
  borderRadius: 10,
  padding: "11px 15px",
  color: "#fff",
  fontWeight: 600,
  cursor: "pointer",
};
export default function DetalleParticipante({
  registroId,
  onCerrar,
  onPagoActualizado,
}: Props) {
  const [participante, setParticipante] =
    useState<Participante | null>(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState("");
  const [mensaje, setMensaje] = useState("");
  const [procesando, setProcesando] =
    useState<string | null>(null);
  const [rechazandoId, setRechazandoId] =
    useState<string | null>(null);
  const [motivo, setMotivo] = useState("");
  const [invitacionQR, setInvitacionQR] = useState<InvitacionQR | null>(null);
  const [vistaInvitacion, setVistaInvitacion] = useState<{ token: string; url: string } | null>(null);
  const urlVistaInvitacion = vistaInvitacion?.token === invitacionQR?.token ? (vistaInvitacion?.url ?? null) : null;
  const [errorVistaInvitacion, setErrorVistaInvitacion] = useState("");

  const cargar = useCallback(async () => {
    const { data: sesion, error: errorSesion } =
      await supabase.auth.getSession();
    if (errorSesion || !sesion.session) {
      throw new Error("Tu sesión ha terminado.");
    }
    const { data, error: errorFuncion } =
      await invocarEvento(
        "detalle-participante",
        {
          method: "POST",
          headers: {
            Authorization:
              `Bearer ${sesion.session.access_token}`,
          },
          body: {
            registro_id: registroId,
          },
        }
      );
    if (errorFuncion) {
      throw new Error(errorFuncion.message);
    }
    if (!data?.ok || !data.participante) {
      throw new Error(
        data?.mensaje ??
        data?.error ??
        "No se pudo obtener el detalle."
      );
    }
    return data.participante as Participante;
  }, [registroId]);
  useEffect(() => {
    let vigente = true;
    cargar()
      .then((datos) => {
        if (vigente) setParticipante(datos);
      })
      .catch((err) => {
        if (vigente) {
          setError(
            err instanceof Error
              ? err.message
              : "Error desconocido"
          );
        }
      })
      .finally(() => {
        if (vigente) setCargando(false);
      });
    return () => {
      vigente = false;
    };
  }, [cargar]);
  async function administrarInvitacion(accion: "cortesia" | "recuperar" | "reemitir") {
    if (!participante || procesando) return;

    const textoConfirmacion = accion === "cortesia"
      ? "¿Confirmas otorgar una cortesía y autorizar la entrada sin pago?"
      : accion === "reemitir"
        ? "¿Reemitir el QR? El código anterior dejará de ser válido."
        : "¿Consultar o generar la invitación? Si ya existe un QR, no se modificará.";

    if (!window.confirm(textoConfirmacion)) return;

    setProcesando(`invitacion-${accion}`);
    setError("");
    setMensaje("");

    try {
      const { data: sesion, error: errorSesion } = await supabase.auth.getSession();
      if (errorSesion || !sesion.session) throw new Error("Tu sesión ha terminado.");

      const { data, error: errorFuncion } = await invocarEvento(
        "administrar-invitacion",
        {
          method: "POST",
          headers: { Authorization: `Bearer ${sesion.session.access_token}` },
          body: { registro_id: participante.id, accion },
        }
      );

      if (errorFuncion) throw new Error(await mensajeErrorFuncion(errorFuncion));
      if (!data?.ok || data?.resultado?.ok === false) {
        throw new Error(data?.resultado?.error ?? data?.error ?? "No se pudo administrar la invitación.");
      }

      const token = extraerToken(data.resultado);
      if (token) {
        setInvitacionQR({ token, registroId: participante.id });
        setMensaje("Invitación generada. Imprímela o guárdala antes de cerrar esta ventana.");
      } else {
        setMensaje("Ya existe una invitación. Si perdiste su imagen, utiliza «Reemitir QR» para crear una nueva; el QR anterior quedará invalidado.");
      }

      const actualizado = await cargar();
      setParticipante(actualizado);
      onPagoActualizado?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo administrar la invitación.");
    } finally {
      setProcesando(null);
    }
  }

  function imprimirInvitacion() {
    if (!invitacionQR || !participante || !urlVistaInvitacion) return;
    window.print();
  }

  function nombreParticipante() {
    return [participante?.promotora?.nombres, participante?.promotora?.apellidos]
      .filter(Boolean).join(" ") || "Participante";
  }

  // Una sola composición para pantalla, impresión, descarga PNG y WhatsApp.
  // La plantilla es únicamente decoración: logo, nombre, folio y QR son datos reales.
  const crearImagenInvitacion = useCallback(async (): Promise<Blob> => {
    if (!invitacionQR || !participante) {
      throw new Error("Primero genera una invitación QR.");
    }
    const qrSvg = document.querySelector<SVGSVGElement>("#qr-invitacion-codigo");
    if (!qrSvg) throw new Error("No se encontró el código QR de esta invitación.");

    const ancho = 1122;
    const alto = 1402;
    const canvas = document.createElement("canvas");
    canvas.width = ancho;
    canvas.height = alto;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("El navegador no permite generar el PNG.");

    const ruta = import.meta.env.BASE_URL;
    const [fondo, logo] = await Promise.all([
      cargarImagenLocal(`${ruta}invitacion-amor-navidad-fondo.png`),
      cargarImagenLocal(`${ruta}amor-logo.png`),
    ]);
    ctx.drawImage(fondo, 0, 0, ancho, alto);

    // Logo ORIGINAL AMOR del proyecto (no se reemplaza ni se redibuja).
    ctx.drawImage(logo, 451, 62, 220, 212);
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";

    ctx.fillStyle = "#99702e";
    ctx.font = "bold 65px Georgia, 'Times New Roman', serif";
    ctx.fillText("EVENTO ANUAL", 561, 365, 810);
    ctx.fillStyle = "#a33460";
    ctx.font = "bold 70px Georgia, 'Times New Roman', serif";
    ctx.fillText("AMOR 2026", 561, 450, 840);

    // Divisores en oro y pequeños copos dibujados en el lienzo.
    const linea = (y: number, izquierda: number, derecha: number) => {
      ctx.strokeStyle = "#bd974c";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(izquierda, y);
      ctx.lineTo(derecha, y);
      ctx.stroke();
    };
    const copo = (x: number, y: number, radio: number) => {
      ctx.save();
      ctx.translate(x, y);
      ctx.strokeStyle = "#bd974c";
      ctx.lineWidth = 2.4;
      for (let i = 0; i < 6; i += 1) {
        ctx.save();
        ctx.rotate(i * Math.PI / 3);
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(0, -radio);
        ctx.moveTo(0, -radio * .69);
        ctx.lineTo(-radio * .2, -radio * .84);
        ctx.moveTo(0, -radio * .69);
        ctx.lineTo(radio * .2, -radio * .84);
        ctx.stroke();
        ctx.restore();
      }
      ctx.restore();
    };
    linea(492, 380, 525);
    linea(492, 595, 742);
    copo(561, 492, 17);

    ctx.font = "32px Georgia, 'Times New Roman', serif";
    ctx.fillStyle = "#956b2f";
    ctx.fillText("INVITACIÓN PERSONAL", 561, 566);

    const nombre = [participante.promotora?.nombres, participante.promotora?.apellidos]
      .filter(Boolean).join(" ").toUpperCase() || "PARTICIPANTE";
    let tamaño = 42;
    while (tamaño > 23) {
      ctx.font = `bold ${tamaño}px Georgia, 'Times New Roman', serif`;
      if (ctx.measureText(nombre).width <= 800) break;
      tamaño -= 2;
    }
    ctx.fillStyle = "#a33460";
    ctx.fillText(nombre, 561, 654, 820);
    ctx.font = "24px Arial, sans-serif";
    ctx.fillStyle = "#51454a";
    ctx.fillText(`Folio: ${participante.folio ?? "—"}`, 561, 696, 835);

    // Código QR verdadero: se conserva negro sobre blanco y con su margen original.
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(376, 735, 370, 370);
    ctx.strokeStyle = "#c69a47";
    ctx.lineWidth = 2.5;
    ctx.strokeRect(374, 733, 374, 374);
    const svg = new XMLSerializer().serializeToString(qrSvg);
    const svgUrl = URL.createObjectURL(new Blob([svg], { type: "image/svg+xml;charset=utf-8" }));
    try {
      const qrImagen = await cargarImagenLocal(svgUrl);
      ctx.drawImage(qrImagen, 384, 743, 354, 354);
    } finally {
      URL.revokeObjectURL(svgUrl);
    }

    linea(1130, 378, 520);
    linea(1130, 602, 746);
    copo(561, 1130, 15);
    ctx.font = "bold 33px Georgia, 'Times New Roman', serif";
    ctx.fillStyle = "#91692e";
    ctx.fillText(eventoActual.fecha.toUpperCase(), 561, 1190, 830);
    ctx.font = "23px Arial, sans-serif";
    ctx.fillStyle = "#5d5354";
    ctx.fillText("Presenta este código al ingresar al evento", 561, 1244, 820);
    ctx.font = "21px Arial, sans-serif";
    ctx.fillText("Invitación personal • Un solo acceso", 561, 1281, 820);
    ctx.font = "19px Arial, sans-serif";
    ctx.fillText((esChiapas ? "SALÓN BLANCO · Tuxtla Gutiérrez, Chiapas" : "Salón RADEV'S 1 · Minatitlán, Veracruz"), 561, 1320, 840);
    ctx.fillText(esChiapas ? "Horario por confirmar" : "Recepción: 1:00 p.m.", 561, 1352, 840);

    return await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) resolve(blob);
        else reject(new Error("No se pudo generar el PNG."));
      }, "image/png");
    });
  }, [invitacionQR, participante]);

  // La vista previa e impresión usan exactamente los mismos píxeles que el PNG.
  useEffect(() => {
    if (!invitacionQR || !participante || invitacionQR.registroId !== participante.id) {
      return;
    }
    let vigente = true;
    let url: string | null = null;
    void crearImagenInvitacion()
      .then(blob => {
        url = URL.createObjectURL(blob);
        if (vigente) {
          setVistaInvitacion({ token: invitacionQR.token, url });
          setErrorVistaInvitacion("");
        } else {
          URL.revokeObjectURL(url);
        }
      })
      .catch(error => {
        if (vigente) {
          setErrorVistaInvitacion(error instanceof Error ? error.message : "No se pudo preparar la vista previa.");
        }
      });
    return () => {
      vigente = false;
      if (url) URL.revokeObjectURL(url);
    };
  }, [crearImagenInvitacion, invitacionQR, participante]);

  function nombreArchivo() {
    const primerNombre = (participante?.promotora?.nombres ?? "participante")
      .trim()
      .split(/\s+/)[0]
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "") || "participante";
    const celular = (participante?.promotora?.telefono_whatsapp ?? "")
      .replace(/\D/g, "");
    return `${primerNombre}-${celular || "sin-celular"}.png`;
  }

  function guardarImagen(blob: Blob) {
    const url = URL.createObjectURL(blob);
    const enlace = document.createElement("a");
    enlace.href = url;
    enlace.download = nombreArchivo();
    document.body.appendChild(enlace);
    enlace.click();
    enlace.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 60000);
  }

  async function descargarInvitacion() {
    setError("");
    try {
      const blob = await crearImagenInvitacion();
      guardarImagen(blob);
      setMensaje("Invitación PNG descargada correctamente.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo descargar la invitación.");
    }
  }

  async function compartirInvitacion() {
    setError("");
    setMensaje("");

    if (!participante || !invitacionQR) return;

    const numero = (participante.promotora?.telefono_whatsapp ?? "")
      .replace(/\D/g, "");

    const telefono = numero.length === 12 && numero.startsWith("52") ? numero.slice(2) : numero;

    // Copiar el teléfono desde el clic del usuario.
    const copiaNumero = telefono
      ? navigator.clipboard.writeText(telefono).then(
          () => true,
          () => false
        )
      : Promise.resolve(false);

    try {
      const blob = await crearImagenInvitacion();

      const archivo = new File(
        [blob],
        nombreArchivo(),
        { type: "image/png" }
      );

      if (
        typeof navigator.share === "function" &&
        typeof navigator.canShare === "function" &&
        navigator.canShare({ files: [archivo] })
      ) {
        try {
          await navigator.share({
            files: [archivo]
          });

          const copiado = await copiaNumero;
          setMensaje(
            copiado
              ? "Número copiado. Pégalo en el buscador de WhatsApp si hace falta."
              : "Selecciona el contacto de la participante en WhatsApp."
          );
          return;
        } catch (error) {
          if (
            error instanceof DOMException &&
            error.name === "AbortError"
          ) {
            return;
          }
          throw error;
        }
      }

      guardarImagen(blob);
      setMensaje(
        "Tu navegador no permite compartir imágenes directamente. " +
        "Se descargó el PNG para adjuntarlo en WhatsApp."
      );

    } catch (error) {
      setError(
        error instanceof Error
          ? error.message
          : "No se pudo compartir la invitación."
      );
    }
  }
  async function validarPago(
    pago: Pago,
    accion: "aprobar" | "rechazar"
  ) {
    if (procesando || pago.estado !== "pendiente") {
      return;
    }
    const motivoLimpio = motivo.trim();
    if (
      accion === "rechazar" &&
      motivoLimpio.length < 5
    ) {
      setError(
        "El motivo de rechazo debe tener al menos 5 caracteres."
      );
      return;
    }
    const confirmado = window.confirm(
      accion === "aprobar"
        ? `¿Confirmas aprobar el pago de ${dinero(pago.importe)}?`
        : `¿Confirmas rechazar el pago de ${dinero(pago.importe)}?`
    );
    if (!confirmado) return;
    setProcesando(pago.id);
    setError("");
    setMensaje("");
    try {
      const { data: sesion, error: errorSesion } =
        await supabase.auth.getSession();
      if (errorSesion || !sesion.session) {
        throw new Error("Tu sesión ha terminado.");
      }
      const { data, error: errorFuncion } =
        await invocarEvento(
          "validar-pago",
          {
            method: "POST",
            headers: {
              Authorization:
                `Bearer ${sesion.session.access_token}`,
            },
            body: {
              pago_id: pago.id,
              accion,
              motivo:
                accion === "rechazar"
                  ? motivoLimpio
                  : null,
            },
          }
        );
      if (errorFuncion) {
        let detalleError = errorFuncion.message;
        const contexto = (
          errorFuncion as {
            context?: Response;
          }
        ).context;
        if (contexto) {
          try {
            const respuesta = await contexto.clone().json();
            detalleError =
              respuesta?.error ?? detalleError;
          } catch {
            // Conservamos el mensaje original.
          }
        }
        throw new Error(detalleError);
      }
      if (!data?.ok) {
        throw new Error(
          data?.error ?? "No se pudo procesar el pago."
        );
      }
      setRechazandoId(null);
      setMotivo("");
      if (accion === "aprobar") {
        const token = extraerToken(data.resultado);
        if (token) setInvitacionQR({ token, registroId });
      }
      const datosActualizados = await cargar();
      setParticipante(datosActualizados);
      setMensaje(
        accion === "aprobar"
          ? "Pago validado correctamente."
          : "Pago rechazado correctamente."
      );
      onPagoActualizado?.();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Ocurrió un error al validar el pago."
      );
      // Actualizamos para detectar si otro administrador
      // ya había procesado este pago.
      try {
        const datosActualizados = await cargar();
        setParticipante(datosActualizados);
      } catch {
        // Conservamos el error original.
      }
    } finally {
      setProcesando(null);
    }
  }
  return (
    <>
      <style>{`@media print {
        @page { size: A4 portrait; margin: 8mm; }
        body * { visibility: hidden !important; }
        #invitacion-impresa, #invitacion-impresa * { visibility: visible !important; }
        #invitacion-impresa {
          position: fixed !important; left: 50% !important; top: 0 !important;
          transform: translateX(-50%) !important;
          width: 188mm !important; max-width: 100% !important;
          padding: 0 !important; margin: 0 !important;
          box-sizing: border-box !important; border: 0 !important;
          box-shadow: none !important; page-break-inside: avoid;
        }
        #invitacion-impresa .invitacion-imagen {
          width: 188mm !important; max-width: 100% !important;
          max-height: 268mm !important; height: auto !important;
          display: block !important; object-fit: contain !important;
        }
        #invitacion-impresa, #invitacion-impresa * {
          print-color-adjust: exact !important;
          -webkit-print-color-adjust: exact !important;
        }
        #invitacion-impresa .no-imprimir { display: none !important; }
      }`}</style>
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Detalle de participante"
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 1000,
        background: "rgba(37, 19, 29, 0.7)",
        overflowY: "auto",
        padding: 16,
      }}
    >
      <div
        style={{
          maxWidth: 780,
          margin: "30px auto",
          background: "#fff6f9",
          borderRadius: 18,
          padding: 24,
        }}
      >
        <header
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: 12,
            marginBottom: 20,
          }}
        >
          <div>
            <h2
              style={{
                color: "#a33460",
                margin: 0,
              }}
            >
              Detalle de participante
            </h2>
            <p style={{ color: "#806e76" }}>
              Información administrativa privada
            </p>
          </div>
          <button
            type="button"
            onClick={onCerrar}
            aria-label="Cerrar detalle"
            style={{
              border: "1px solid #e5bdcc",
              borderRadius: 10,
              background: "#fff",
              padding: 10,
              cursor: "pointer",
            }}
          >
            <X size={22} />
          </button>
        </header>
        {cargando && (
          <p>
            <RefreshCw size={17} />
            {" "}Consultando información...
          </p>
        )}
        {mensaje && (
          <p
            role="status"
            style={{
              color: "#166534",
              background: "#dcfce7",
              padding: 14,
              borderRadius: 10,
            }}
          >
            {mensaje}
          </p>
        )}
        {error && (
          <p
            role="alert"
            style={{
              color: "#991b1b",
              background: "#fee2e2",
              padding: 14,
              borderRadius: 10,
            }}
          >
            {error}
          </p>
        )}
        {participante && (
          <div
            style={{
              display: "grid",
              gap: 18,
            }}
          >
            <section style={tarjeta}>
              <h3
                style={{
                  color: "#a33460",
                  display: "flex",
                  gap: 8,
                  alignItems: "center",
                }}
              >
                <UserRound size={21} />
                Datos de inscripción
              </h3>
              <p>
                <strong>Folio:</strong>{" "}
                {participante.folio ?? "—"}
              </p>
              <p>
                <strong>Nombre:</strong>{" "}
                {[
                  participante.promotora?.nombres,
                  participante.promotora?.apellidos,
                ]
                  .filter(Boolean)
                  .join(" ") || "—"}
              </p>
              <p>
                <strong>WhatsApp:</strong>{" "}
                {participante.promotora
                  ?.telefono_whatsapp ?? "—"}
              </p>
              <p>
                <strong>Estado:</strong>{" "}
                {participante.promotora
                  ?.estado_residencia ?? "—"}
              </p>
              <p>
                <strong>Asesor:</strong>{" "}
                {participante.asesor?.nombre ?? "—"}
              </p>
              <p>
                <strong>Evento:</strong>{" "}
                {participante.evento?.nombre ?? "—"}
              </p>
              <p>
                <strong>Estado de inscripción:</strong>{" "}
                {participante.estado ?? "—"}
              </p>
              <p>
                <strong>Fecha:</strong>{" "}
                {fecha(participante.created_at)}
              </p>
              {participante.promotora?.foto_url && (
                <div>
                  <strong>Fotografía</strong>
                  <div style={{ marginTop: 12 }}>
                    <img
                      src={
                        participante.promotora.foto_url
                      }
                      alt="Fotografía de participante"
                      referrerPolicy="no-referrer"
                      style={{
                        maxWidth: 220,
                        maxHeight: 260,
                        objectFit: "contain",
                        borderRadius: 12,
                      }}
                    />
                  </div>
                </div>
              )}
            </section>
            <section style={tarjeta}>
              <h3 style={{ color: "#a33460", display: "flex", alignItems: "center", gap: 8 }}>
                <QrCode size={21} /> Invitación y acceso
              </h3>
              <p style={{ color: "#806e76" }}>
                La invitación se emite al aprobar el pago o autorizar una cortesía.
                Por seguridad, el código solo puede mostrarse cuando se genera.
              </p>
              <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
                {!participante.exento_pago && participante.estado !== "confirmado" && (
                  <button type="button" disabled={procesando !== null}
                    onClick={() => void administrarInvitacion("cortesia")}
                    style={{ ...botonBase, background: "#a33460", opacity: procesando ? 0.6 : 1 }}>
                    <Gift size={18} /> Otorgar cortesía
                  </button>
                )}
                {participante.estado === "confirmado" && (
                  <>
                    <button type="button" disabled={procesando !== null}
                      onClick={() => void administrarInvitacion("recuperar")}
                      style={{ ...botonBase, background: "#7c3aed", opacity: procesando ? 0.6 : 1 }}>
                      <QrCode size={18} /> Consultar / generar QR
                    </button>
                    <button type="button" disabled={procesando !== null}
                      onClick={() => void administrarInvitacion("reemitir")}
                      style={{ ...botonBase, background: "#9a3412", opacity: procesando ? 0.6 : 1 }}>
                      <RefreshCw size={18} /> Reemitir QR
                    </button>
                  </>
                )}
              </div>
              {invitacionQR?.registroId === participante.id && (
                <div id="invitacion-impresa" style={{ margin: "22px auto", maxWidth: 600, textAlign: "center", background: "#fff", padding: 10, borderRadius: 14, boxShadow: "0 12px 34px rgba(61, 34, 29, 0.12)" }}>
                  {/* SVG del token real: fuente de la exportación, nunca el QR decorativo del boceto. */}
                  <div aria-hidden="true" style={{ position: "absolute", width: 1, height: 1, overflow: "hidden", opacity: 0, pointerEvents: "none" }}>
                    <QRCodeSVG id="qr-invitacion-codigo" value={invitacionQR.token} size={360} level="H" marginSize={4} />
                  </div>
                  {urlVistaInvitacion ? (
                    <img className="invitacion-imagen" src={urlVistaInvitacion} alt={`Invitación del Evento Anual AMOR 2026 para ${nombreParticipante()}`} style={{ width: "100%", height: "auto", display: "block", borderRadius: 8 }} />
                  ) : (
                    <div className="no-imprimir" style={{ padding: "45px 15px", color: "#806e76" }}>
                      {errorVistaInvitacion ? `No se pudo mostrar el diseño: ${errorVistaInvitacion}` : "Preparando invitación con tu logo original..."}
                      {errorVistaInvitacion && <div style={{ marginTop: 15 }}><QRCodeSVG value={invitacionQR.token} size={240} level="H" marginSize={4} /></div>}
                    </div>
                  )}
                  <div className="no-imprimir" style={{ display: "flex", justifyContent: "center", gap: 10, flexWrap: "wrap", marginTop: 18 }}>
                    <button type="button" onClick={imprimirInvitacion} disabled={!urlVistaInvitacion}
                      style={{ ...botonBase, background: "#a33460", opacity: urlVistaInvitacion ? 1 : .55 }}>
                      <Printer size={18} /> Imprimir
                    </button>
                    <button type="button" onClick={() => void descargarInvitacion()}
                      style={{ ...botonBase, background: "#99723c" }}>
                      <Download size={18} /> Descargar PNG
                    </button>
                    <button type="button" onClick={() => void compartirInvitacion()}
                      style={{ ...botonBase, background: "#15803d" }}>
                      <MessageCircle size={18} /> Compartir por WhatsApp
                    </button>
                  </div>
                  <p className="no-imprimir" style={{ fontSize: 12, color: "#806e76" }}>
                    El QR es único y se incorpora sin modificarlo. Al compartir, se abre WhatsApp directamente y se descarga la imagen para adjuntarla manualmente.
                  </p>
                </div>
              )}
            </section>

<section style={tarjeta}>
              <h3
                style={{
                  color: "#a33460",
                  display: "flex",
                  gap: 8,
                  alignItems: "center",
                }}
              >
                <Receipt size={21} />
                Información de pagos
              </h3>
              {participante.exento_pago && (
                <p>Participante exenta de pago.</p>
              )}
              {participante.pagos.length === 0 && (
                <p>No hay pagos registrados.</p>
              )}
              {participante.pagos.map((pago) => (
                <div
                  key={pago.id}
                  style={{
                    padding: 15,
                    marginTop: 12,
                    background: "#fff6f9",
                    borderRadius: 12,
                  }}
                >
                  <p>
                    <strong>Importe:</strong>{" "}
                    {dinero(pago.importe)}
                  </p>
                  <p>
                    <strong>Estado:</strong>{" "}
                    <span
                      style={{
                        fontWeight: 700,
                        color:
                          pago.estado === "validado"
                            ? "#15803d"
                            : pago.estado === "rechazado"
                            ? "#b91c1c"
                            : "#a16207",
                      }}
                    >
                      {pago.estado ?? "—"}
                    </span>
                  </p>
                  <p>
                    <strong>Referencia:</strong>{" "}
                    {pago.referencia ?? "—"}
                  </p>
                  <p>
                    <strong>Cuenta destino:</strong>{" "}
                    {pago.cuenta_destino ?? "—"}
                  </p>
                  <p>
                    <strong>Registrado:</strong>{" "}
                    {fecha(pago.created_at)}
                  </p>
                  {pago.validado_at && (
                    <p>
                      <strong>Procesado:</strong>{" "}
                      {fecha(pago.validado_at)}
                    </p>
                  )}
                  {pago.comprobante_url ? (
                    <a
                      href={pago.comprobante_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      referrerPolicy="no-referrer"
                      style={{
                        display: "inline-block",
                        background: "#a33460",
                        color: "#fff",
                        borderRadius: 10,
                        padding: "11px 15px",
                        textDecoration: "none",
                        marginBottom: 12,
                      }}
                    >
                      Ver comprobante privado
                    </a>
                  ) : (
                    <p style={{ color: "#806e76" }}>
                      Comprobante no disponible.
                    </p>
                  )}
                  {pago.estado === "pendiente" && (
                    <div
                      style={{
                        marginTop: 16,
                        paddingTop: 16,
                        borderTop: "1px solid #f0d5df",
                      }}
                    >
                      <p
                        style={{
                          fontWeight: 600,
                          color: "#806e76",
                        }}
                      >
                        Validación administrativa
                      </p>
                      <div
                        style={{
                          display: "flex",
                          gap: 10,
                          flexWrap: "wrap",
                        }}
                      >
                        <button
                          type="button"
                          disabled={procesando !== null}
                          onClick={() =>
                            void validarPago(pago, "aprobar")
                          }
                          style={{
                            ...botonBase,
                            background: "#15803d",
                            opacity:
                              procesando !== null ? 0.6 : 1,
                          }}
                        >
                          <CheckCircle2 size={18} />
                          {procesando === pago.id
                            ? "Procesando..."
                            : "Aprobar pago"}
                        </button>
                        <button
                          type="button"
                          disabled={procesando !== null}
                          onClick={() => {
                            setError("");
                            setRechazandoId(
                              rechazandoId === pago.id
                                ? null
                                : pago.id
                            );
                            setMotivo("");
                          }}
                          style={{
                            ...botonBase,
                            background: "#b91c1c",
                            opacity:
                              procesando !== null ? 0.6 : 1,
                          }}
                        >
                          <XCircle size={18} />
                          Rechazar pago
                        </button>
                      </div>
                      {rechazandoId === pago.id && (
                        <div style={{ marginTop: 16 }}>
                          <label
                            htmlFor={`motivo-${pago.id}`}
                            style={{
                              display: "block",
                              marginBottom: 8,
                              fontWeight: 600,
                              color: "#a33460",
                            }}
                          >
                            Motivo del rechazo
                          </label>
                          <textarea
                            id={`motivo-${pago.id}`}
                            value={motivo}
                            onChange={(e) =>
                              setMotivo(e.target.value)
                            }
                            rows={3}
                            maxLength={500}
                            placeholder="Escribe el motivo del rechazo..."
                            style={{
                              width: "100%",
                              padding: 12,
                              border: "1px solid #e5bdcc",
                              borderRadius: 10,
                              boxSizing: "border-box",
                              resize: "vertical",
                              font: "inherit",
                            }}
                          />
                          <button
                            type="button"
                            disabled={
                              procesando !== null ||
                              motivo.trim().length < 5
                            }
                            onClick={() =>
                              void validarPago(pago, "rechazar")
                            }
                            style={{
                              ...botonBase,
                              marginTop: 10,
                              background: "#991b1b",
                              opacity:
                                procesando !== null ||
                                motivo.trim().length < 5
                                  ? 0.6
                                  : 1,
                            }}
                          >
                            Confirmar rechazo
                          </button>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </section>
            <p
              style={{
                display: "flex",
                gap: 8,
                alignItems: "center",
                fontSize: 13,
                color: "#806e76",
              }}
            >
              <ShieldCheck size={17} />
              Los enlaces de archivos caducan
              aproximadamente 60 segundos
              después de generarse.
            </p>
          </div>
        )}
      </div>
    </div>
    </>
  );
}
