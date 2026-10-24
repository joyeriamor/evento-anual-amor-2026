import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.117.3";

// Este endpoint es público porque no requiere cuenta; la protección obligatoria
// es Turnstile + validaciones de servidor y un interruptor independiente.
const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*", // Sin cookies ni sesiones privadas.
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};
const EVENTO_ID = "43e67bda-d19d-4c0e-a639-e85f2d62f294";
const MAX_ARCHIVO = 5 * 1024 * 1024;
// Control complementario por IP. Para redes compartidas se usa un umbral
// moderado; el límite puede ajustarse luego de medir tráfico real.
const MAX_INTENTOS_IP = 20;
const VENTANA_MINUTOS_IP = 15;
const EXTENSIONES: Record<string, string> = {
  "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp",
};
const CUENTAS: Record<string, string> = {
  "bbva-laura": "BBVA (Bancomer) · Laura Azucena Vázquez Puig · ****1772",
  "bbva-rufino": "BBVA (Bancomer) · Rufino Terán Juárez · ****0689",
  "coppel-laura": "BanCoppel · Laura Azucena Vázquez Puig · ****8878",
  "coppel-rufino": "BanCoppel · Rufino Terán Juárez · ****1539",
};
const ESTADOS = new Set([
  "Aguascalientes", "Baja California", "Baja California Sur", "Campeche",
  "Chiapas", "Chihuahua", "Ciudad de México", "Coahuila", "Colima",
  "Durango", "Guanajuato", "Guerrero", "Hidalgo", "Jalisco",
  "Estado de México", "Michoacán", "Morelos", "Nayarit", "Nuevo León",
  "Oaxaca", "Puebla", "Querétaro", "Quintana Roo", "San Luis Potosí",
  "Sinaloa", "Sonora", "Tabasco", "Tamaulipas", "Tlaxcala",
  "Veracruz", "Yucatán", "Zacatecas",
]);

function responder(codigo: number, cuerpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: codigo,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function texto(fd: FormData, nombre: string): string {
  const valor = fd.get(nombre);
  return typeof valor === "string" ? valor.trim() : "";
}

function formatoValido(file: File): boolean {
  return !!EXTENSIONES[file.type] && file.size >= 1 && file.size <= MAX_ARCHIVO;
}

async function magicValido(file: File): Promise<boolean> {
  const b = new Uint8Array(await file.slice(0, 16).arrayBuffer());
  if (file.type === "image/jpeg") return b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;
  if (file.type === "image/png") return b.length >= 8 &&
    [137, 80, 78, 71, 13, 10, 26, 10].every((v, i) => b[i] === v);
  if (file.type === "image/webp") return b.length >= 12 &&
    String.fromCharCode(...b.slice(0, 4)) === "RIFF" &&
    String.fromCharCode(...b.slice(8, 12)) === "WEBP";
  return false;
}

async function comprobarTurnstile(token: string, req: Request): Promise<boolean> {
  const secret = Deno.env.get("TURNSTILE_SECRET_KEY");
  if (!secret || token.length < 20 || token.length > 2500) return false;
  const body = new URLSearchParams({ secret, response: token });
  const ip = req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  if (ip) body.set("remoteip", ip);
  const respuesta = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST", body, signal: AbortSignal.timeout(10000),
  });
  if (!respuesta.ok) return false;
  // El dominio se comprueba con el hostname devuelto por Cloudflare,
  // no con Origin/Host aportados por el navegador. Por defecto SOLO
  // localhost: al publicar, configurar TURNSTILE_ALLOWED_HOSTNAMES
  // (lista de dominios separados por comas) en los secretos de Supabase.
  const permitidos = new Set(
    (Deno.env.get("TURNSTILE_ALLOWED_HOSTNAMES") ?? "localhost")
      .split(",")
      .map((hostname) => hostname.trim().toLowerCase())
      .filter(Boolean)
  );
  const resultado = await respuesta.json() as {
    success?: boolean;
    hostname?: string;
  };
  const hostname = typeof resultado.hostname === "string"
    ? resultado.hostname.trim().toLowerCase()
    : "";
  if (resultado.success !== true || !hostname || !permitidos.has(hostname)) {
    console.warn("Turnstile rechazado o dominio no autorizado.", {
      valido: resultado.success === true,
      hostname,
    });
    return false;
  }
  return true;
}

// La identificación IP depende de las cabeceras proporcionadas por la
// infraestructura de Supabase. Priorizar cf-connecting-ip cuando exista;
// si solo está x-forwarded-for, tomar el último salto (el más próximo al gateway)
// para no confiar sin más en el primer valor que podría enviar un cliente.
// Es un control complementario, no una prueba criptográfica de identidad.
function ipCliente(req: Request): string | null {
  const ip = (
    req.headers.get("cf-connecting-ip")?.trim() ||
    req.headers.get("x-forwarded-for")?.split(",").at(-1)?.trim() ||
    ""
  );
  if (!ip || ip.length > 45 || !/^[0-9a-fA-F:.]+$/.test(ip) ||
      (!ip.includes(".") && !ip.includes(":"))) return null;
  return ip;
}

// La base de datos recibe solo un identificador HMAC; nunca la IP en claro.
async function hashLimite(ip: string, secreto: string): Promise<string> {
  const codificador = new TextEncoder();
  const clave = await crypto.subtle.importKey(
    "raw", codificador.encode(secreto),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const firma = new Uint8Array(await crypto.subtle.sign(
    "HMAC", clave, codificador.encode(`registro-v2:ip:${ip}`)
  ));
  return Array.from(firma, byte => byte.toString(16).padStart(2, "0")).join("");
}

async function comprobarLimiteRegistro(req: Request, supabase: SupabaseClient): Promise<
  "permitido" | "limitado" | "error"
> {
  const secreto = Deno.env.get("REGISTRO_RATE_LIMIT_SECRET");
  const ip = ipCliente(req);
  if (!secreto || !ip) {
    console.error("No se pudo verificar el control de solicitudes: falta secreto o IP de gateway.");
    return "error"; // Fail closed: no permitir eludir el límite.
  }
  try {
    const clave = await hashLimite(ip, secreto);
    const { data, error } = await supabase.rpc("comprobar_limite_registro", {
      p_clave: clave,
      p_max_intentos: MAX_INTENTOS_IP,
      p_ventana_minutos: VENTANA_MINUTOS_IP,
    });
    if (error) {
      console.error("No se pudo consultar el limitador:", error.message);
      return "error";
    }
    if (data === true) return "permitido";
    if (data === false) return "limitado";
    console.error("Respuesta inesperada del limitador.");
    return "error";
  } catch (err) {
    console.error("Error de limitación de solicitudes:", err instanceof Error ? err.message : String(err));
    return "error";
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return responder(405, { ok: false, mensaje: "Método no permitido." });

  // El público permanece cerrado por defecto, aunque el frontend se modifique.
  if (Deno.env.get("REGISTROS_HABILITADOS") !== "true") {
    return responder(403, { ok: false, mensaje: "Las inscripciones todavía no están habilitadas." });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const maxRaw = Deno.env.get("MAX_REGISTROS_EVENTO");
  const maxRegistros = maxRaw && /^\d+$/.test(maxRaw) ? Number(maxRaw) : null;
  if (!url || !serviceKey || !Deno.env.get("TURNSTILE_SECRET_KEY") ||
      !Deno.env.get("REGISTRO_RATE_LIMIT_SECRET") ||
      !maxRegistros || maxRegistros < 1) {
    console.error("Registro público mal configurado: credenciales, captcha o cupo faltantes.");
    return responder(503, { ok: false, mensaje: "El registro todavía no está configurado para recibir solicitudes." });
  }

  const longitud = Number(req.headers.get("content-length") ?? 0);
  if (longitud > 11 * 1024 * 1024) {
    return responder(413, { ok: false, mensaje: "El tamaño total de archivos supera el permitido." });
  }
  const contentType = req.headers.get("content-type") ?? "";
  if (!contentType.startsWith("multipart/form-data")) {
    return responder(415, { ok: false, mensaje: "El registro requiere un formulario con fotografías." });
  }

  // Contar intentos antes de parsear el formulario o subir archivos.
  // El cliente service_role llama la RPC; los visitantes no pueden llamarla.
  const supabase = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const veredicto = await comprobarLimiteRegistro(req, supabase);
  if (veredicto === "limitado") {
    return new Response(JSON.stringify({
      ok: false,
      mensaje: "Demasiados intentos de registro. Intenta nuevamente en 15 minutos.",
    }), {
      status: 429,
      headers: {
        ...CORS,
        "Content-Type": "application/json; charset=utf-8",
        "Retry-After": String(VENTANA_MINUTOS_IP * 60),
      },
    });
  }
  if (veredicto !== "permitido") {
    return responder(503, {
      ok: false,
      mensaje: "No fue posible verificar el límite de solicitudes. Intenta más tarde.",
    });
  }

  let datos: FormData;
  try {
    datos = await req.formData();
  } catch {
    return responder(400, { ok: false, mensaje: "No se pudo interpretar el formulario." });
  }

  const nombres = texto(datos, "nombres");
  const apellidos = texto(datos, "apellidos");
  const estado = texto(datos, "estado");
  const whatsapp = texto(datos, "whatsapp");
  const asesorId = texto(datos, "asesor_id");
  const tipo = texto(datos, "tipo_participante");
  const grupo = texto(datos, "grupo_ruta");
  const cuentaId = texto(datos, "cuenta_destino");
  const token = texto(datos, "turnstile_token");
  const foto = datos.get("foto");
  const comprobante = datos.get("comprobante");
  const fotoArchivo = foto instanceof File ? foto : null;
  const comprobanteArchivo = comprobante instanceof File ? comprobante : null;

  // La categoría EMPLEADO se verifica en el servidor, no con una casilla del cliente.
  // Sólo el asesor activo cuyo nombre sea EMPLEADO tiene este tratamiento.
  const { data: asesor, error: asesorError } = await supabase
    .from("asesores").select("nombre,activo").eq("id", asesorId).maybeSingle();
  if (asesorError) {
    console.error("No se pudo comprobar el asesor:", asesorError.message);
    return responder(503, { ok: false, mensaje: "No se pudo verificar el asesor. Intenta más tarde." });
  }
  if (!asesor?.activo) {
    return responder(400, { ok: false, mensaje: "Selecciona un asesor válido." });
  }
  const esEmpleado = String(asesor.nombre).trim().toUpperCase() === "EMPLEADO";
  const tipoNormalizado = esEmpleado ? "promotora" : tipo;
  const requierePago = !esEmpleado && tipoNormalizado === "vendedora";
  const grupoNormalizado = esEmpleado ? null : grupo;
  const grupoCorrecto = esEmpleado || (grupo.length >= 2 && grupo.length <= 60);
  const tipoCorrecto = esEmpleado
    ? (tipo === "" || tipo === "promotora")
    : (tipo === "vendedora" || tipo === "promotora");
  const pagoCorrecto = !requierePago || (
    !!CUENTAS[cuentaId] && !!comprobanteArchivo &&
    formatoValido(comprobanteArchivo) && await magicValido(comprobanteArchivo)
  );

  if (nombres.length < 2 || nombres.length > 100 || apellidos.length < 2 ||
      apellidos.length > 100 || !ESTADOS.has(estado) || !/^\d{10}$/.test(whatsapp) || /^(\d)\1{9}$/.test(whatsapp) ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(asesorId) ||
      !tipoCorrecto || !grupoCorrecto || !pagoCorrecto ||
      texto(datos, "privacidad_aceptada") !== "true" ||
      !fotoArchivo || !formatoValido(fotoArchivo) || !(await magicValido(fotoArchivo))) {
    return responder(400, {
      ok: false, mensaje: "Verifica datos, grupo (excepto EMPLEADO), fotografía y, para VENDEDORA, cuenta y comprobante (JPG, PNG o WebP, hasta 5 MB).",
    });
  }

  try {
    if (!(await comprobarTurnstile(token, req))) {
      return responder(400, { ok: false, mensaje: "La verificación de seguridad caducó o no es válida. Intenta nuevamente." });
    }
  } catch {
    return responder(503, { ok: false, mensaje: "No fue posible verificar la seguridad. Intenta más tarde." });
  }

  const idSolicitud = crypto.randomUUID();
  const fotoPath = `${EVENTO_ID}/${idSolicitud}.${EXTENSIONES[fotoArchivo.type]}`;
  const comprobantePath = requierePago && comprobanteArchivo
    ? `${EVENTO_ID}/${idSolicitud}.${EXTENSIONES[comprobanteArchivo.type]}` : null;
  const fotoBucket = "fotos-promotoras";
  const comprobanteBucket = "comprobantes-pago";
  let fotoSubida = false;
  let comprobanteSubido = false;
  let guardado = false;

  try {
    // Subidas privadas. El usuario nunca recibe permisos de Storage.
    const subidaFoto = await supabase.storage.from(fotoBucket).upload(
      fotoPath, fotoArchivo, { contentType: fotoArchivo.type, upsert: false, cacheControl: "0" }
    );
    if (subidaFoto.error) throw subidaFoto.error;
    fotoSubida = true;

    // PROMOTORA y EMPLEADO no pagan ni suben comprobante.
    if (requierePago && comprobantePath && comprobanteArchivo) {
      const subidaComprobante = await supabase.storage.from(comprobanteBucket).upload(
        comprobantePath, comprobanteArchivo,
        { contentType: comprobanteArchivo.type, upsert: false, cacheControl: "0" }
      );
      if (subidaComprobante.error) throw subidaComprobante.error;
      comprobanteSubido = true;
    }

    const { data, error } = await supabase.rpc("crear_registro_publico_v3", {
      p_evento_id: EVENTO_ID,
      p_asesor_id: asesorId,
      p_nombres: nombres,
      p_apellidos: apellidos,
      p_estado_residencia: estado,
      p_whatsapp: whatsapp,
      p_tipo_participante: tipoNormalizado,
      p_grupo_ruta: grupoNormalizado,
      p_foto_path: fotoPath,
      p_comprobante_path: comprobantePath,
      p_cuenta_destino: requierePago ? CUENTAS[cuentaId] : null,
      p_max_registros: maxRegistros,
    });
    if (error) throw error;
    const resultado = data as { ok?: boolean; codigo?: string; mensaje?: string; folio?: string } | null;
    if (!resultado?.ok) {
      return responder(["DUPLICADO", "SIN_CUPO"].includes(resultado?.codigo ?? "") ? 409 : 400, {
        ok: false, codigo: resultado?.codigo, mensaje: resultado?.mensaje ?? "No fue posible completar el registro.",
      });
    }
    guardado = true;
    return responder(200, {
      ok: true, folio: resultado.folio, estado: "pendiente",
      mensaje: requierePago
        ? "Inscripción recibida. Tu pago está pendiente de revisión."
        : "Inscripción recibida. Cortesía pendiente de autorización del administrador; todavía no hay QR.",
    });
  } catch (err) {
    const detalle = err instanceof Error ? err.message : "desconocido";
    console.error("Error al procesar el registro público:", detalle);
    if (detalle.includes('CUPO_COMPLETO')) {
      return responder(409, { ok: false, codigo: 'SIN_CUPO', mensaje: 'Cupo completo. Ya no quedan lugares disponibles para este evento.' });
    }
    return responder(500, { ok: false, mensaje: "No se pudo guardar el registro. Intenta más tarde o contacta a administración." });
  } finally {
    // Cuando la transacción falla, los archivos huérfanos se eliminan.
    if (!guardado) {
      if (fotoSubida) await supabase.storage.from(fotoBucket).remove([fotoPath]);
      if (comprobanteSubido && comprobantePath) await supabase.storage.from(comprobanteBucket).remove([comprobantePath]);
    }
  }
});
