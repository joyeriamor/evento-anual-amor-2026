import { strToU8, zipSync } from "fflate";

const ns = "http://schemas.openxmlformats.org";
const hojas = `${ns}/spreadsheetml/2006/main`;
const relaciones = `${ns}/officeDocument/2006/relationships`;

function textoXml(texto: string): string {
  // XML 1.0 excludes control characters and invalid Unicode code points.
  return Array.from(texto)
    .filter((caracter) => {
      const punto = caracter.codePointAt(0)!;
      return punto === 9 || punto === 10 || punto === 13 ||
        (punto >= 32 && punto <= 0xd7ff) || (punto >= 0xe000 && punto <= 0xfffd) || punto >= 0x10000;
    })
    .join("")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

export function crearReporteAsesor(filas: readonly string[][]): Uint8Array<ArrayBuffer> {
  const celdas = [["Nombre completo", "Estado", "Grupo"], ...filas]
    .map((fila, indice) => `<row r="${indice + 1}">${fila.map((valor, columna) =>
      `<c r="${"ABC"[columna]}${indice + 1}" t="inlineStr"><is><t xml:space="preserve">${textoXml(valor)}</t></is></c>`,
    ).join("")}</row>`).join("");

  const archivos = {
    "[Content_Types].xml": `<Types xmlns="${ns}/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>`,
    "_rels/.rels": `<Relationships xmlns="${ns}/package/2006/relationships"><Relationship Id="rId1" Type="${relaciones}/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
    "xl/workbook.xml": `<workbook xmlns="${hojas}" xmlns:r="${relaciones}"><sheets><sheet name="Participantes" sheetId="1" r:id="rId1"/></sheets></workbook>`,
    "xl/_rels/workbook.xml.rels": `<Relationships xmlns="${ns}/package/2006/relationships"><Relationship Id="rId1" Type="${relaciones}/worksheet" Target="worksheets/sheet1.xml"/></Relationships>`,
    "xl/worksheets/sheet1.xml": `<worksheet xmlns="${hojas}"><sheetData>${celdas}</sheetData></worksheet>`,
  };

  const zip = zipSync(Object.fromEntries(
    Object.entries(archivos).map(([nombre, xml]) => [nombre, strToU8(xml)]),
  ));
  return new Uint8Array(zip);
}

export function descargarReporteAsesor(filas: readonly string[][]) {
  const archivo = new Blob([crearReporteAsesor(filas)], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  const url = URL.createObjectURL(archivo);
  const enlace = document.createElement("a");
  enlace.href = url;
  enlace.download = "participantes-del-asesor.xlsx";
  enlace.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
