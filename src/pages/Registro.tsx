
import {
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type FormEvent,
} from "react";

import {
  ArrowLeft,
  Camera,
  ImagePlus,
  CheckCircle2,
  RefreshCw,
  Landmark,
  Copy,
  Upload,
  AlertCircle,
  LockKeyhole,
} from "lucide-react";

import SelectorAsesor from "./SelectorAsesor";
import AvisoPrivacidad from "../components/AvisoPrivacidad";
import TurnstileRegistro from "../components/TurnstileRegistro";
import { supabase } from "../lib/supabase";

import "./Registro.css";

// Cerrado por defecto: VITE_REGISTROS_HABILITADOS no abre el servidor por sí solo.
// El servidor comprueba REGISTROS_HABILITADOS y Turnstile por separado.
const REGISTROS_HABILITADOS = import.meta.env.VITE_REGISTROS_HABILITADOS === "true";

const estados = [
  "Aguascalientes",
  "Baja California",
  "Baja California Sur",
  "Campeche",
  "Chiapas",
  "Chihuahua",
  "Ciudad de México",
  "Coahuila",
  "Colima",
  "Durango",
  "Guanajuato",
  "Guerrero",
  "Hidalgo",
  "Jalisco",
  "Estado de México",
  "Michoacán",
  "Morelos",
  "Nayarit",
  "Nuevo León",
  "Oaxaca",
  "Puebla",
  "Querétaro",
  "Quintana Roo",
  "San Luis Potosí",
  "Sinaloa",
  "Sonora",
  "Tabasco",
  "Tamaulipas",
  "Tlaxcala",
  "Veracruz",
  "Yucatán",
  "Zacatecas",
];

const cuentas = [
  {
    id: "bbva-laura",
    banco: "BBVA (Bancomer)",
    titular: "Laura Azucena Vázquez Puig",
    numero: "4152313225081772",
  },
  {
    id: "bbva-rufino",
    banco: "BBVA (Bancomer)",
    titular: "Rufino Terán Juárez",
    numero: "4152313982050689",
  },
  {
    id: "coppel-laura",
    banco: "BanCoppel",
    titular: "Laura Azucena Vázquez Puig",
    numero: "4169161427718878",
  },
  {
    id: "coppel-rufino",
    banco: "BanCoppel",
    titular: "Rufino Terán Juárez",
    numero: "4169160464571539",
  },
];

const MAX_ARCHIVO = 5 * 1024 * 1024;

const TIPOS = [
  "image/jpeg",
  "image/png",
  "image/webp",
];

type Props = {
  onVolver: () => void;
  /** Solo cambia la interfaz; la autorización real se hace en la Edge Function. */
  modoPruebaAdmin?: boolean;
  evento?: "minatitlan" | "chiapas";
};

export default function Registro({ onVolver, modoPruebaAdmin = false, evento = "minatitlan" }: Props) {
  const formularioHabilitado = evento === "chiapas" ? false : (modoPruebaAdmin || REGISTROS_HABILITADOS);
  const camaraRef = useRef<HTMLInputElement>(null);
  const galeriaRef = useRef<HTMLInputElement>(null);

  const [foto, setFoto] = useState<File | null>(null);

  // Elección única, obligatoria para cada nueva inscripción.
  const [tipoParticipante, setTipoParticipante] =
    useState<"vendedora" | "promotora" | "">("");

  const [vistaPrevia, setVistaPrevia] =
    useState<string | null>(null);

  const [comprobante, setComprobante] =
    useState<File | null>(null);

  const [cuentaElegida, setCuentaElegida] =
    useState("");

  // Se determina por el asesor REAL seleccionado (no por datos manipulables del usuario).
  const [asesorEmpleado, setAsesorEmpleado] = useState(false);
  const [grupoRuta, setGrupoRuta] = useState("");
  const [registroCortesia, setRegistroCortesia] = useState(false);
  const requierePago = !asesorEmpleado && tipoParticipante === "vendedora";
  const esCortesia = asesorEmpleado || tipoParticipante === "promotora";

  const [copiado, setCopiado] = useState("");

  const [aceptaPrivacidad, setAceptaPrivacidad] =
    useState(false);
  const [confirmaPrueba, setConfirmaPrueba] = useState(false);

  const [error, setError] = useState("");
  const [enviando, setEnviando] = useState(false);
  const [tokenSeguridad, setTokenSeguridad] = useState("");
  const [intentoTurnstile, setIntentoTurnstile] = useState(0);
  const [folioRegistrado, setFolioRegistrado] = useState<string | null>(null);
  // Evita enviar varias veces mientras se espera respuesta.
  const envioEnCurso = useRef(false);

  useEffect(() => () => { if (vistaPrevia) URL.revokeObjectURL(vistaPrevia); }, [vistaPrevia]);

  function guardarFoto(archivo: File | null) {
    setFoto(archivo);
    setVistaPrevia(archivo ? URL.createObjectURL(archivo) : null);
  }

  function validarArchivo(
    event: ChangeEvent<HTMLInputElement>,
    guardar: (archivo: File | null) => void
  ) {
    const archivo = event.target.files?.[0] ?? null;

    if (!archivo) {
      guardar(null);
      return;
    }

    if (!TIPOS.includes(archivo.type)) {
      setError(
        "Solo se aceptan imágenes JPG, PNG o WebP."
      );

      event.target.value = "";
      guardar(null);
      return;
    }

    if (archivo.size === 0 || archivo.size > MAX_ARCHIVO) {
      setError(
        "El archivo debe pesar entre 1 byte y 5 MB."
      );

      event.target.value = "";
      guardar(null);
      return;
    }

    setError("");
    guardar(archivo);
  }

  async function copiarNumero(numero: string) {
    try {
      await navigator.clipboard.writeText(numero);
      setCopiado(numero);
    } catch {
      setError(
        "No se pudo copiar automáticamente. " +
        "Mantén presionado el número para copiarlo."
      );
    }
  }

  async function enviarRegistro(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (envioEnCurso.current) return;
    if (!formularioHabilitado) {
      setError("Las inscripciones todavía no están habilitadas.");
      return;
    }

    const formulario = event.currentTarget;
    const datos = new FormData(formulario);
    const nombres = String(datos.get("nombres") ?? "").trim();
    const apellidos = String(datos.get("apellidos") ?? "").trim();
    const estado = String(datos.get("estado") ?? "").trim();
    const asesor = String(datos.get("asesor") ?? "").trim();
    const whatsapp = String(datos.get("whatsapp") ?? "").trim();

    if (nombres.length < 2 || apellidos.length < 2 || !estado || !asesor) {
      setError("Completa tu nombre, apellidos, estado y asesor.");
      return;
    }
    if (!/^\d{10}$/.test(whatsapp) || /^(\d)\1{9}$/.test(whatsapp)) {
      setError("Escribe un WhatsApp válido de 10 dígitos.");
      return;
    }
    if (!asesorEmpleado && tipoParticipante !== "vendedora" && tipoParticipante !== "promotora") {
      setError("Indica si eres vendedora o promotora.");
      return;
    }
    if (!asesorEmpleado && (grupoRuta.trim().length < 2 || grupoRuta.trim().length > 60)) {
      setError("GRUPO es obligatorio y debe tener entre 2 y 60 caracteres.");
      return;
    }
    if (!foto || !TIPOS.includes(foto.type) || foto.size < 1 || foto.size > MAX_ARCHIVO) {
      setError("La fotografía es obligatoria: JPG, PNG o WebP de hasta 5 MB.");
      return;
    }
    if (requierePago && !cuentas.some((cuenta) => cuenta.id === cuentaElegida)) {
      setError("Selecciona la cuenta a la que realizaste tu transferencia.");
      return;
    }
    if (requierePago && (!comprobante || !TIPOS.includes(comprobante.type) || comprobante.size < 1 || comprobante.size > MAX_ARCHIVO)) {
      setError("Adjunta tu comprobante: JPG, PNG o WebP de hasta 5 MB.");
      return;
    }
    if (!aceptaPrivacidad) {
      setError("Debes aceptar el aviso de privacidad.");
      return;
    }
    if (modoPruebaAdmin) {
      if (!/^PRUEBA(?:[ -]|$)/i.test(nombres)) {
        setError('Para una inscripción de prueba, el nombre debe comenzar con «PRUEBA ».');
        return;
      }
      if (!confirmaPrueba) {
        setError('Confirma que utilizas datos ficticios y que no realizaste ningún pago real.');
        return;
      }
    } else if (!tokenSeguridad) {
      setError("Completa la verificación de seguridad antes de enviar.");
      return;
    }

    datos.set("asesor_id", asesor);
    datos.delete("asesor");
    // EMPLEADO se normaliza a promotora por compatibilidad con la BD.
    // El servidor revalida el asesor y el tipo: no confía en estos datos del cliente.
    datos.set("tipo_participante", asesorEmpleado ? "promotora" : tipoParticipante);
    datos.set("grupo_ruta", asesorEmpleado ? "" : grupoRuta.trim());
    if (requierePago) {
      datos.set("cuenta_destino", cuentaElegida);
    } else {
      datos.delete("cuenta_destino");
      datos.delete("cuenta_transferencia");
      datos.delete("comprobante");
    }
    datos.set("privacidad_aceptada", "true");
    if (modoPruebaAdmin) {
      datos.set("confirmar_prueba", "true");
      datos.delete("turnstile_token");
    } else {
      datos.set("turnstile_token", tokenSeguridad);
    }
    datos.set("foto", foto);
    if (requierePago && comprobante) datos.set("comprobante", comprobante);

    envioEnCurso.current = true;
    setEnviando(true);
    setError("");
    try {
      // FormData se manda como multipart/form-data; no establecer Content-Type a mano.
      // El modo prueba usa una función separada, protegida por sesión de administrador.
      const opciones: { method: "POST"; body: FormData; headers?: Record<string, string> } = {
        method: "POST", body: datos,
      };
      if (modoPruebaAdmin) {
        const { data: sesion, error: errorSesion } = await supabase.auth.getSession();
        if (errorSesion || !sesion.session) throw new Error("Inicia sesión como administrador.");
        opciones.headers = { Authorization: `Bearer ${sesion.session.access_token}` };
      }
      const { data, error: fallo } = await supabase.functions.invoke(
        modoPruebaAdmin ? "registrar-prueba-admin" : evento === "chiapas" ? "registrar-participante-chiapas" : "registrar-participante-v2",
        opciones
      );
      if (fallo) {
        let detalle = fallo.message;
        const contexto = (fallo as { context?: Response }).context;
        if (contexto instanceof Response) {
          try {
            const respuesta = await contexto.clone().json();
            detalle = respuesta?.mensaje || respuesta?.error || detalle;
          } catch { /* respuesta sin JSON */ }
        }
        throw new Error(detalle);
      }
      if (data?.ok !== true || typeof data?.folio !== "string") {
        throw new Error(data?.mensaje ?? "El servidor no confirmó tu inscripción.");
      }
      setRegistroCortesia(esCortesia);
      setFolioRegistrado(data.folio);
      formulario.reset();
      guardarFoto(null);
      setComprobante(null);
      setTipoParticipante("");
      setGrupoRuta("");
      setAsesorEmpleado(false);
      setCuentaElegida("");
      setAceptaPrivacidad(false);
      setConfirmaPrueba(false);
      setTokenSeguridad("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo enviar el registro.");
      // Cada respuesta de Turnstile solo puede utilizarse una vez.
      setTokenSeguridad("");
      setIntentoTurnstile((anterior) => anterior + 1);
    } finally {
      envioEnCurso.current = false;
      setEnviando(false);
    }
  }

  if (folioRegistrado) {
    return (
      <section className="registro-contenedor">
        <div className="registro-exito" role="status">
          <CheckCircle2 size={46} color="#15803d" />
          <h1>{modoPruebaAdmin ? "¡Registro de prueba creado!" : "¡Recibimos tu inscripción!"}</h1>
          <p>Tu folio es <strong>{folioRegistrado}</strong>.</p>
          <p>{registroCortesia
            ? "Cortesía pendiente de autorización del administrador. Guarda tu folio; aún no tienes QR de acceso."
            : modoPruebaAdmin
              ? "Marcado como PRUEBA. El comprobante ficticio queda pendiente de revisión."
              : "Tu comprobante está pendiente de revisión. Guarda el folio; aún no tienes QR de acceso."}</p>
          <button type="button" className="registro-volver" onClick={onVolver}>
            <ArrowLeft size={18} /> Volver al inicio
          </button>
        </div>
      </section>
    );
  }

  return (
    <section className="registro-contenedor">
      <button
        type="button"
        className="registro-volver"
        onClick={onVolver}
      >
        <ArrowLeft size={18} />
        Volver al inicio
      </button>

      <div className="registro-encabezado">
        <h1>{modoPruebaAdmin ? "Registro de prueba · Administración" : "Registro de participantes"}</h1>
        <p>Evento Anual AMOR 2026</p>
      </div>
      {modoPruebaAdmin && (
        <div role="note" style={{ background: "#fffae8", border: "2px solid #d8ad47", borderRadius: 12, padding: 16, marginBottom: 20, color: "#6f4c23" }}>
          <strong>SOLO PRUEBAS · NO ABRE INSCRIPCIONES PÚBLICAS</strong>
          <p style={{ marginBottom: 0 }}>
            Escribe un nombre que comience con <b>PRUEBA </b> y usa un WhatsApp ficticio de 10 dígitos que no pertenezca a nadie.
            Adjunta una fotografía ficticia o autorizada. Solo si seleccionas VENDEDORA deberás adjuntar un comprobante ficticio. <b>No realices ninguna transferencia.</b>
            El registro se identificará como PRUEBA y no ocupará un lugar del cupo real.
          </p>
        </div>
      )}

      <form
        className="registro-formulario"
        onSubmit={enviarRegistro}
      >
        <p className="registro-obligatorios">
          Completa los campos visibles. La fotografía personal es obligatoria para todos.
        </p>



        <div className="registro-grid">
          <label>
            Nombre(s) *
            <input
              name="nombres"
              required
              maxLength={100}
              placeholder="Escribe tus nombres"
            />
          </label>

          <label>
            Apellidos *
            <input
              name="apellidos"
              required
              maxLength={100}
              placeholder="Escribe tus apellidos"
            />
          </label>

          <label>
            Estado de residencia *
            <select
              name="estado"
              required
              defaultValue=""
            >
              <option value="" disabled>
                Selecciona tu estado
              </option>

              {estados.map((estado) => (
                <option
                  key={estado}
                  value={estado}
                >
                  {estado}
                </option>
              ))}
            </select>
          </label>

          <SelectorAsesor excluirEmpleados={evento === "chiapas"} onChange={(seleccionado) => {
            const empleado = seleccionado?.nombre.trim().toLocaleUpperCase("es-MX") === "EMPLEADO";
            setAsesorEmpleado(empleado);
            setTipoParticipante("");
            setComprobante(null);
            setCuentaElegida("");
            if (empleado) setGrupoRuta("");
            setError("");
          }} />

          {!asesorEmpleado && (
            <label className="registro-ancho">
              GRUPO *
              <input
                name="grupo_ruta"
                maxLength={60}
                minLength={2}
                required
                value={grupoRuta}
                onChange={(e) => setGrupoRuta(e.target.value)}
                placeholder="Grupo de ruta al que perteneces"
              />
            </label>
          )}

          <label className="registro-ancho">
            Número de WhatsApp *
            <input
              name="whatsapp"
              type="tel"
              inputMode="numeric"
              pattern="[0-9]{10}"
              maxLength={10}
              required
              placeholder="10 dígitos"
            />
            <small>
              Sin espacios ni código de país.
            </small>
          </label>
        </div>

        {!asesorEmpleado && (
        <fieldset className="registro-tipo-participante">
          <legend>¿Cómo participas en el Evento Anual AMOR? *</legend>
          <p>Selecciona únicamente una opción.</p>
          <div className="registro-tipo-opciones">
            <label className={tipoParticipante === "vendedora" ? "seleccionada" : ""}>
              <input
                type="radio"
                name="tipo_participante"
                value="vendedora"
                checked={tipoParticipante === "vendedora"}
                onChange={() => setTipoParticipante("vendedora")}
                required
              />
              Vendedora
            </label>
            <label className={tipoParticipante === "promotora" ? "seleccionada" : ""}>
              <input
                type="radio"
                name="tipo_participante"
                value="promotora"
                checked={tipoParticipante === "promotora"}
                onChange={() => {
                  setTipoParticipante("promotora");
                  setCuentaElegida("");
                  setComprobante(null);
                }}
                required
              />
              Promotora
            </label>
          </div>
        </fieldset>
        )}

        <div className="registro-foto-seccion">
          <h2>Tu fotografía *</h2>

          <p>
            Toma una selfie o selecciona una
            fotografía clara de tu rostro.
          </p>

          {vistaPrevia ? (
            <div className="registro-foto-preview">
              <img
                src={vistaPrevia}
                alt="Vista previa de fotografía"
              />

              <span>
                <CheckCircle2 size={17} />
                Fotografía seleccionada
              </span>

              <button
                type="button"
                className="registro-cambiar-foto"
                onClick={() =>
                  galeriaRef.current?.click()
                }
              >
                <RefreshCw size={17} />
                Cambiar fotografía
              </button>
            </div>
          ) : (
            <div className="registro-foto-placeholder">
              <Camera size={42} />
              <span>
                Aquí aparecerá tu fotografía
              </span>
            </div>
          )}

          <div className="registro-foto-botones">
            <button
              type="button"
              className="registro-btn-camara"
              onClick={() =>
                camaraRef.current?.click()
              }
            >
              <Camera size={19} />
              Tomar selfie
            </button>

            <button
              type="button"
              className="registro-btn-galeria"
              onClick={() =>
                galeriaRef.current?.click()
              }
            >
              <ImagePlus size={19} />
              Subir fotografía
            </button>
          </div>

          <input
            aria-label="Fotografía de rostro tomada con cámara"
            ref={camaraRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            capture="user"
            onChange={(e) =>
              validarArchivo(e, guardarFoto)
            }
            style={{ display: "none" }}
          />

          <input
            aria-label="Fotografía de rostro desde galería"
            ref={galeriaRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            onChange={(e) =>
              validarArchivo(e, guardarFoto)
            }
            style={{ display: "none" }}
          />
        </div>

        {esCortesia && (
          <div role="status" style={{ padding: 16, marginTop: 18, borderRadius: 12, background: "#f0f8f3", color: "#176747" }}>
            <strong>Registro con cortesía pendiente</strong>
            <p style={{ marginBottom: 0 }}>
              No necesitas cuenta bancaria ni comprobante. El administrador debe autorizar tu cortesía antes de emitir el QR.
            </p>
          </div>
        )}

        {requierePago && (
          <>
        <div className="amor-pagos">
          <div className="amor-pagos-titulo">
            <Landmark size={25} />

            <div>
              <h2>
                {modoPruebaAdmin ? "Cuenta simulada del comprobante" : "¿Dónde realizar mi transferencia?"}
              </h2>
              <p>
                {modoPruebaAdmin ? "Elige una cuenta únicamente para el registro ficticio. No transfieras dinero." : "Selecciona una de las cuentas disponibles."}
              </p>
            </div>
          </div>

          <div className="amor-cuota">
            <span>Cuota de inscripción</span>
            <strong>$300.00 MXN</strong>
          </div>

          <div className="amor-cuentas">
            {cuentas.map((cuenta) => (
              <div
                key={cuenta.id}
                className={
                  "amor-cuenta " +
                  (
                    cuentaElegida === cuenta.id
                      ? "seleccionada"
                      : ""
                  )
                }
              >
                <label className="amor-cuenta-datos">
                  <input
                    type="radio"
                    name="cuenta_transferencia"
                    value={cuenta.id}
                    checked={
                      cuentaElegida === cuenta.id
                    }
                    onChange={() =>
                      setCuentaElegida(cuenta.id)
                    }
                    required
                  />

                  <span>
                    <strong>
                      {cuenta.banco}
                    </strong>

                    <small>
                      {cuenta.titular}
                    </small>

                    <span className="amor-numero">
                      {cuenta.numero
                        .replace(/(.{4})/g, "$1 ")
                        .trim()}
                    </span>
                  </span>
                </label>

                <button
                  type="button"
                  className="amor-copiar"
                  onClick={() =>
                    copiarNumero(cuenta.numero)
                  }
                >
                  {copiado === cuenta.numero ? (
                    <CheckCircle2 size={16} />
                  ) : (
                    <Copy size={16} />
                  )}

                  {copiado === cuenta.numero
                    ? "Copiado"
                    : "Copiar"}
                </button>
              </div>
            ))}
          </div>

          <div className="amor-pago-aviso">
            <AlertCircle size={20} />

            <p>
              {modoPruebaAdmin ? (
                <>NO transfieras dinero. Selecciona una cuenta de ejemplo y adjunta
                un comprobante ficticio creado por ti, sin datos bancarios reales.
                El pago quedará pendiente como parte de la prueba.</>
              ) : (
                <>Transfiere exactamente <strong>$300.00 MXN</strong> a una
                de las cuentas indicadas. Conserva tu comprobante para
                adjuntarlo a tu inscripción. El pago será revisado por administración.</>
              )}
            </p>
          </div>
        </div>

        <div className="registro-comprobante">
          <Upload size={28} />

          <div>
            <strong>
              Adjuntar comprobante de transferencia *
            </strong>

            <p>
              Imagen JPG, PNG o WebP de máximo 5 MB.
            </p>
          </div>

          <input
            type="file"
            accept="image/jpeg,image/png,image/webp"
            required
            onChange={(e) =>
              validarArchivo(e, setComprobante)
            }
          />

          {comprobante && (
            <small>
              <CheckCircle2 size={16} />
              {comprobante.name}
            </small>
          )}
        </div>

          </>
        )}

        {/* AVISO DE PRIVACIDAD INTEGRADO */}

        <AvisoPrivacidad
          aceptado={aceptaPrivacidad}
          onChange={(valor) => {
            setAceptaPrivacidad(valor);

            if (valor) {
              setError("");
            }
          }}
        />

        {!modoPruebaAdmin && (REGISTROS_HABILITADOS || import.meta.env.DEV) && (
  <TurnstileRegistro key={intentoTurnstile} onToken={setTokenSeguridad} />
)}

        {modoPruebaAdmin && (
          <label style={{ display: "flex", alignItems: "flex-start", gap: 10, margin: "20px 0", fontWeight: 600, color: "#80571d" }}>
            <input type="checkbox" checked={confirmaPrueba} onChange={(e) => setConfirmaPrueba(e.target.checked)} required />
            Confirmo que es una prueba con datos ficticios y sin transferencia real.
          </label>
        )}

        {error && (
          <p
            className="registro-error"
            role="alert"
          >
            {error}
          </p>
        )}

        <button
          className="registro-enviar"
          type="submit"
          disabled={
            !aceptaPrivacidad ||
            !formularioHabilitado ||
            (modoPruebaAdmin ? !confirmaPrueba : !tokenSeguridad) ||
            enviando
          }
          style={{
            opacity:
              aceptaPrivacidad &&
              formularioHabilitado &&
              (modoPruebaAdmin ? confirmaPrueba : !!tokenSeguridad) &&
              !enviando
                ? 1
                : 0.55,
            cursor:
              aceptaPrivacidad &&
              formularioHabilitado &&
              (modoPruebaAdmin ? confirmaPrueba : !!tokenSeguridad) &&
              !enviando
                ? "pointer"
                : "not-allowed",
          }}
        >
          {formularioHabilitado ? (
            enviando ? "Enviando registro..." : modoPruebaAdmin ? "Guardar registro de prueba" : "Enviar mi registro"
          ) : (
            <>
              <LockKeyhole
                size={18}
                style={{
                  verticalAlign: "middle",
                  marginRight: 8,
                }}
              />
              Inscripciones próximamente
            </>
          )}
        </button>

        {!formularioHabilitado && (
          <p
            style={{
              textAlign: "center",
              fontSize: 13,
              color: "#856b75",
              marginTop: 10,
            }}
          >
            Estamos preparando el registro
            del Evento Anual AMOR 2026.
            Por ahora no se reciben
            inscripciones ni comprobantes.
          </p>
        )}
      </form>
    </section>
  );
}
