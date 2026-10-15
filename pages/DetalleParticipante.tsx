
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
  const cargar = useCallback(async () => {
    const { data: sesion, error: errorSesion } =
      await supabase.auth.getSession();
    if (errorSesion || !sesion.session) {
      throw new Error("Tu sesión ha terminado.");
    }
    const { data, error: errorFuncion } =
      await supabase.functions.invoke(
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
    setCargando(true);
    setError("");
    setMensaje("");
    setParticipante(null);
    setRechazandoId(null);
    setMotivo("");
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
        : "¿Generar la invitación para esta inscripción confirmada?";

    if (!window.confirm(textoConfirmacion)) return;

    setProcesando(`invitacion-${accion}`);
    setError("");
    setMensaje("");

    try {
      const { data: sesion, error: errorSesion } = await supabase.auth.getSession();
      if (errorSesion || !sesion.session) throw new Error("Tu sesión ha terminado.");

      const { data, error: errorFuncion } = await supabase.functions.invoke(
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
        setMensaje("La invitación ya existe, pero su token no puede recuperarse. Usa «Reemitir QR» para obtener uno nuevo.");
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
    if (!invitacionQR || !participante) return;
    window.print();
  }

  function nombreParticipante() {
    return [participante?.promotora?.nombres, participante?.promotora?.apellidos]
      .filter(Boolean).join(" ") || "Participante";
  }

  // Exportación local: no se envía el token QR a servicios externos.
  async function crearImagenInvitacion(): Promise<Blob> {
    if (!invitacionQR || !participante) throw new Error("Primero genera una invitación QR.");
    const svg = document.querySelector<SVGSVGElement>("#qr-invitacion-codigo");
    if (!svg) throw new Error("No se encontró el QR en pantalla.");

    const canvas = document.createElement("canvas");
    canvas.width = 1080;
    canvas.height = 1450;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Tu navegador no permite generar imágenes.");

    // Invitación navideña: el QR permanece sin filtros ni alteraciones.
    const fondo = ctx.createLinearGradient(0, 0, 1080, 1450);
    fondo.addColorStop(0, "#fff9ee");
    fondo.addColorStop(0.55, "#fff6f9");
    fondo.addColorStop(1, "#f1fff6");
    ctx.fillStyle = fondo;
    ctx.fillRect(0, 0, 1080, 1450);
    ctx.strokeStyle = "#b9944e";
    ctx.lineWidth = 12;
    ctx.strokeRect(42, 42, 996, 1366);
    ctx.strokeStyle = "#dfc7a2";
    ctx.lineWidth = 3;
    ctx.strokeRect(64, 64, 952, 1322);

    // Ramas de acebo en las cuatro esquinas de la tarjeta.
    for (const [x, y, espejo] of [[115, 125, 1], [965, 125, -1], [115, 1330, 1], [965, 1330, -1]] as const) {
      ctx.save();
      ctx.translate(x, y);
      ctx.scale(espejo, 1);
      ctx.fillStyle = "#1b7345";
      ctx.beginPath();
      ctx.ellipse(-25, -10, 31, 12, -0.65, 0, Math.PI * 2);
      ctx.ellipse(24, -10, 31, 12, 0.65, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#bd2948";
      for (const [bx, by] of [[-9, 11], [9, 10], [0, 26]]) {
        ctx.beginPath();
        ctx.arc(bx, by, 10, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }
    ctx.textAlign = "center";
    ctx.fillStyle = "#a33460";
    ctx.font = "bold 30px Arial, sans-serif";
    ctx.fillText("JOYERÍA AMOR", 540, 175);
    ctx.fillStyle = "#1c7044";
    ctx.font = "bold 58px Georgia, serif";
    ctx.fillText("EVENTO ANUAL", 540, 265);
    ctx.fillStyle = "#a33460";
    ctx.fillText("AMOR 2026", 540, 337);
    ctx.fillStyle = "#98763d";
    ctx.font = "bold 27px Arial, sans-serif";
    ctx.fillText("INVITACIÓN PERSONAL", 540, 420);

    // Ajustar nombres largos sin recortarlos.
    const nombre = nombreParticipante().toUpperCase();
    let tamano = 42;
    do {
      ctx.font = `bold ${tamano}px Arial, sans-serif`;
      if (ctx.measureText(nombre).width <= 910 || tamano <= 20) break;
      tamano -= 2;
    } while (true);
    ctx.fillStyle = "#a33460";
    ctx.fillText(nombre, 540, 505);
    ctx.font = "26px Arial, sans-serif";
    ctx.fillStyle = "#66525c";
    ctx.fillText(`Folio: ${participante.folio ?? "—"}`, 540, 560, 920);

    const xml = new XMLSerializer().serializeToString(svg);
    const qrUrl = URL.createObjectURL(new Blob([xml], { type: "image/svg+xml;charset=utf-8" }));
    try {
      const img = new Image();
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve();
        img.onerror = () => reject(new Error("No se pudo convertir el QR a imagen."));
        img.src = qrUrl;
      });
      ctx.fillStyle = "#fff";
      ctx.fillRect(282, 610, 516, 516);
      ctx.drawImage(img, 302, 630, 476, 476);
    } finally {
      URL.revokeObjectURL(qrUrl);
    }

    ctx.fillStyle = "#1c7044";
    ctx.font = "bold 32px Arial, sans-serif";
    ctx.fillText("6 DE DICIEMBRE DE 2026", 540, 1220);
    ctx.fillStyle = "#66525c";
    ctx.font = "23px Arial, sans-serif";
    ctx.fillText("Presenta este código al ingresar al evento.", 540, 1280);
    ctx.fillText("Salón RADEV'S 1 · Minatitlán, Veracruz", 540, 1320);
    ctx.font = "bold 22px Arial, sans-serif";
    ctx.fillStyle = "#98763d";
    ctx.fillText("INVITACIÓN PERSONAL · UN SOLO ACCESO", 540, 1360);

    return await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error("No se pudo generar el PNG.")), "image/png");
    });
  }

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
    if (!participante || !invitacionQR) return;
    try {
      const blob = await crearImagenInvitacion();
      const archivo = new File([blob], nombreArchivo(), { type: "image/png" });
      const texto = `Hola ${nombreParticipante()}, te compartimos tu invitación a la Evento Anual AMOR 2026. Folio: ${participante.folio ?? "—"}. Presenta el QR adjunto en el acceso.`;
      const compartir = navigator as Navigator & {
        canShare?: (data: ShareData) => boolean;
        share?: (data: ShareData) => Promise<void>;
      };
      if (compartir.share && compartir.canShare?.({ files: [archivo] })) {
        try {
          await compartir.share({ files: [archivo], title: "Invitación Evento Anual AMOR 2026", text: texto });
          setMensaje("Se abrió el menú para compartir la imagen. Selecciona WhatsApp.");
          return;
        } catch (err) {
          if (err instanceof DOMException && err.name === "AbortError") return;
          // Si el navegador no permite compartir, continuamos con WhatsApp Web.
        }
      }
      guardarImagen(blob);
      const numero = (participante.promotora?.telefono_whatsapp ?? "").replace(/\D/g, "");
      const telefono = numero.length === 10 ? `52${numero}` : numero;
      const destino = telefono.length >= 10 ? `https://wa.me/${telefono}?text=${encodeURIComponent(texto)}` : `https://api.whatsapp.com/send?text=${encodeURIComponent(texto)}`;
      window.open(destino, "_blank", "noopener,noreferrer");
      setMensaje("Se descargó el PNG y se abrió WhatsApp. Adjunta manualmente la imagen descargada antes de enviarla.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo compartir la invitación.");
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
        await supabase.functions.invoke(
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
        @page { size: auto; margin: 12mm; }
        body * { visibility: hidden !important; }
        #invitacion-impresa { print-color-adjust: exact !important; -webkit-print-color-adjust: exact !important; }
        #invitacion-impresa, #invitacion-impresa * { visibility: visible !important; }
        #invitacion-impresa { position: absolute !important; left: 0; top: 0; width: 100%; box-sizing: border-box; page-break-inside: avoid; }
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
                      <QrCode size={18} /> Generar invitación
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
                <div id="invitacion-impresa" style={{ marginTop: 20, padding: 24, border: "3px solid #b9944e", borderRadius: 18, background: "linear-gradient(145deg, #fff9ee 0%, #fff6f9 55%, #f1fff6 100%)", textAlign: "center", boxShadow: "0 14px 35px rgba(107, 55, 64, 0.14)" }}>
                  <p style={{ color: "#1c7044", fontSize: 24, margin: "0 0 6px" }} aria-hidden="true">❄ ✦ ❄</p>
                  <p style={{ color: "#98763d", margin: "4px 0", fontWeight: 800, letterSpacing: 2 }}>JOYERÍA AMOR</p>
                  <h2 style={{ color: "#1c7044", fontFamily: "Georgia, serif", margin: "8px 0 4px" }}>EVENTO ANUAL AMOR 2026</h2>
                  <p style={{ marginTop: 0, color: "#a33460", fontWeight: 600 }}>Invitación personal · Edición navideña</p>
                  <p style={{ fontSize: 18 }}><strong>{[participante.promotora?.nombres, participante.promotora?.apellidos].filter(Boolean).join(" ") || "Participante"}</strong></p>
                  <p>Folio: <strong>{participante.folio ?? "—"}</strong></p>
                  <div style={{ display: "flex", justifyContent: "center", margin: "18px 0" }}>
                    <div style={{ background: "#fff", border: "2px solid #dfc7a2", borderRadius: 14, padding: 12 }}>
                      <QRCodeSVG id="qr-invitacion-codigo" value={invitacionQR.token} size={240} level="H" marginSize={4} />
                    </div>
                  </div>
                  <p style={{ color: "#1c7044", fontWeight: 700, marginBottom: 6 }}>6 DE DICIEMBRE DE 2026</p>
                  <p style={{ fontSize: 13, color: "#66525c", marginTop: 0 }}>Salón RADEV'S 1 · Minatitlán, Veracruz</p>
                  <p style={{ fontSize: 12, color: "#806e76" }}>Presenta este QR en el acceso. Invitación personal válida para una sola entrada.</p>
                  <div className="no-imprimir" style={{ display: "flex", justifyContent: "center", gap: 10, flexWrap: "wrap", marginTop: 18 }}>
                    <button type="button" onClick={imprimirInvitacion}
                      style={{ ...botonBase, background: "#a33460" }}>
                      <Printer size={18} /> Imprimir
                    </button>
                    <button type="button" onClick={() => void descargarInvitacion()}
                      style={{ ...botonBase, background: "#7c3aed" }}>
                      <Download size={18} /> Descargar PNG
                    </button>
                    <button type="button" onClick={() => void compartirInvitacion()}
                      style={{ ...botonBase, background: "#15803d" }}>
                      <MessageCircle size={18} /> Compartir por WhatsApp
                    </button>
                  </div>
                  <p className="no-imprimir" style={{ fontSize: 12, color: "#806e76" }}>
                    En celulares compatibles se comparte la imagen directamente. En PC se descarga el PNG y se abre WhatsApp para adjuntarlo.
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
