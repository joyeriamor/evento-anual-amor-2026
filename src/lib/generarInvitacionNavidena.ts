import { esChiapas, eventoActual } from './evento';
/**
 * Generador de invitaciones para el personal validador.
 * Mantiene exactamente la composición del boceto navideño aprobado en
 * DetalleParticipante.tsx. QR, nombre, folio y logotipo son reales.
 * No transmite el QR a ningún servidor externo.
 */

function cargarImagenLocal(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const imagen = new Image();
    imagen.onload = () => resolve(imagen);
    imagen.onerror = () => reject(new Error(`No se pudo cargar el recurso visual: ${url}`));
    imagen.src = url;
  });
}

export async function generarInvitacionNavidena({
  qrSvg, nombre, folio,
}: {
  qrSvg: SVGSVGElement;
  nombre: string;
  folio: string;
}): Promise<Blob> {
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

    const nombreMayusculas = nombre.trim().toUpperCase() || "PARTICIPANTE";
    let tamaño = 42;
    while (tamaño > 23) {
      ctx.font = `bold ${tamaño}px Georgia, 'Times New Roman', serif`;
      if (ctx.measureText(nombreMayusculas).width <= 800) break;
      tamaño -= 2;
    }
    ctx.fillStyle = "#a33460";
    ctx.fillText(nombreMayusculas, 561, 654, 820);
    ctx.font = "24px Arial, sans-serif";
    ctx.fillStyle = "#51454a";
    ctx.fillText(`Folio: ${folio || "—"}`, 561, 696, 835);

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
    ctx.fillText((esChiapas ? "Tuxtla Gutiérrez, Chiapas · Salón por definir" : "Salón RADEV'S 1 · Minatitlán, Veracruz"), 561, 1320, 840);

    return await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) resolve(blob);
        else reject(new Error("No se pudo generar el PNG."));
      }, "image/png");
    });
}
