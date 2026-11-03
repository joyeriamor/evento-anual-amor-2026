import QRCode from "npm:qrcode@1.5.4";
import { render } from "jsr:@nick/resvg@0.1.0-rc.1";
import type { Contexto } from "./whatsapp-motor.ts";
const ROOT = "https://joyeriamor.github.io/evento-anual-amor-2026/";
const W=1122,H=1402;
function escapeXml(value:string):string {
  return Array.from(value, ch => { const n=ch.charCodeAt(0); return n<32 || (n>=127 && n<=159) ? " " : ch; }).join("")
    .replace(/[&<>"']/g,(s)=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&apos;"}[s]??s));
}
function toBase64(bytes:Uint8Array):string {
  let result="";
  for(let i=0;i<bytes.length;i+=8192)
    result+=String.fromCharCode(...bytes.subarray(i,i+8192));
  return btoa(result);
}
export async function pngFromPublicAsset(file:string):Promise<string> {
  // No URL ni dominio suministrado por participantes: rutas fijas del proyecto.
  const response=await fetch(ROOT+file,{redirect:"error",signal:AbortSignal.timeout(9000)});
  if(!response.ok || !response.headers.get("content-type")?.includes("image/png"))
    throw new Error("No se pudo leer el recurso gráfico autorizado");
  const len=Number(response.headers.get("content-length")??0);
  if(len>3_000_000)throw new Error("Recurso gráfico demasiado grande");
  const raw=new Uint8Array(await response.arrayBuffer());
  if(raw.length>3_000_000 || raw.length<100 || raw[0]!==0x89 || raw[1]!==0x50 ||
     raw[2]!==0x4e || raw[3]!==0x47)throw new Error("PNG de diseño inválido");
  return "data:image/png;base64,"+toBase64(raw);
}
export function svgDesign(input:{
  background:string; logo:string; qr:string; nombre:string; folio:string;
  fecha:string; lugar:string; horario:string;
}):string {
  const fontSize=input.nombre.length>45?24:input.nombre.length>35?29:
    input.nombre.length>28?34:42;
  // Sólo permite texto escapado en el SVG.
  const nombre=escapeXml(input.nombre), folio=escapeXml(input.folio);
  const fecha=escapeXml(input.fecha.toLocaleUpperCase("es-MX"));
  const lugar=escapeXml(input.lugar), horario=escapeXml(input.horario);
  // El SVG QR generado por qrcode lleva su propia geometría: se inserta sin cambiar módulos.
  const qr=input.qr.replace(/<svg\b/, '<svg x="384" y="743"');
  if(qr===input.qr || !qr.includes("<svg"))throw new Error("SVG del QR inválido");
  return '<?xml version="1.0" encoding="UTF-8"?>'+
  '<svg xmlns="http://www.w3.org/2000/svg" width="'+W+'" height="'+H+'" viewBox="0 0 '+W+' '+H+'">'+
  '<image href="'+input.background+'" x="0" y="0" width="'+W+'" height="'+H+'"/>'+
  '<image href="'+input.logo+'" x="451" y="62" width="220" height="212"/>'+
  '<g text-anchor="middle">'+
  '<text x="561" y="365" font-family="Bitter,serif" font-size="65" font-weight="bold" fill="#99702e">EVENTO ANUAL</text>'+
  '<text x="561" y="450" font-family="Bitter,serif" font-size="70" font-weight="bold" fill="#a33460">AMOR 2026</text>'+
  '<text x="561" y="566" font-family="Bitter,serif" font-size="32" fill="#956b2f">INVITACIÓN PERSONAL</text>'+
  '<text x="561" y="654" font-family="Inter,sans-serif" font-size="'+fontSize+'" font-weight="bold" fill="#a33460"'+
  (input.nombre.length>45?' textLength="820" lengthAdjust="spacingAndGlyphs"':'')+'>'+nombre+'</text>'+
  '<text x="561" y="696" font-family="Inter,sans-serif" font-size="24" fill="#51454a">Folio: '+folio+'</text>'+
  '</g>'+
  '<g stroke="#bd974c" stroke-width="2.5">'+
  '<path d="M380 492 H525 M595 492 H742 M378 1130 H520 M602 1130 H746"/>'+
  '</g>'+
  '<rect x="374" y="733" width="374" height="374" fill="white" stroke="#c69a47" stroke-width="2.5"/>'+
  qr+
  '<g text-anchor="middle">'+
  '<text x="561" y="1190" font-family="Bitter,serif" font-size="33" font-weight="bold" fill="#91692e">'+fecha+'</text>'+
  '<text x="561" y="1244" font-family="Inter,sans-serif" font-size="23" fill="#5d5354">Presenta este código al ingresar al evento</text>'+
  '<text x="561" y="1281" font-family="Inter,sans-serif" font-size="21" fill="#5d5354">Invitación personal · Un solo acceso</text>'+
  '<text x="561" y="1320" font-family="Inter,sans-serif" font-size="19" fill="#5d5354">'+lugar+'</text>'+
  '<text x="561" y="1352" font-family="Inter,sans-serif" font-size="19" fill="#5d5354">'+horario+'</text>'+
  '</g></svg>';
}


/** Backend only: receives exactly the token recovered and hash-checked from Vault. */
export async function generarImagen(c: Contexto): Promise<Uint8Array> {
 const qr=await QRCode.toString(c.token_qr,{type:"svg",width:354,margin:4,
  errorCorrectionLevel:"H",color:{dark:"#000000",light:"#FFFFFFFF"}});
 const [background,logo]=await Promise.all([
  pngFromPublicAsset("invitacion-amor-navidad-fondo.png"),pngFromPublicAsset("amor-logo.png")]);
 const png=render(svgDesign({background,logo,qr,nombre:c.participante.toLocaleUpperCase("es-MX").slice(0,120),
  folio:c.folio,fecha:c.fecha,lugar:c.lugar,horario:"Recepción: "+c.recepcion}));
 if(png.length<200 || png.length>5_000_000 || png[0]!==137 || png[1]!==80 || png[2]!==78 || png[3]!==71)
  throw new Error("imagen_invalida");
 return new Uint8Array(png);
}
