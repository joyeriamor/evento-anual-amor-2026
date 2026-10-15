
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

import "./Registro.css";

const REGISTROS_HABILITADOS = false;

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
};

export default function Registro({ onVolver }: Props) {
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

  const [copiado, setCopiado] = useState("");

  const [aceptaPrivacidad, setAceptaPrivacidad] =
    useState(false);

  const [error, setError] = useState("");

  useEffect(() => {
    if (!foto) {
      setVistaPrevia(null);
      return;
    }

    const url = URL.createObjectURL(foto);

    setVistaPrevia(url);

    return () => URL.revokeObjectURL(url);
  }, [foto]);

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

  function enviarRegistro(
    event: FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();

    if (!REGISTROS_HABILITADOS) {
      setError(
        "Las inscripciones todavía no están habilitadas."
      );
      return;
    }

    const datos = new FormData(event.currentTarget);
    const nombres = String(datos.get("nombres") ?? "").trim();
    const apellidos = String(datos.get("apellidos") ?? "").trim();
    const estado = String(datos.get("estado") ?? "").trim();
    const asesor = String(datos.get("asesor") ?? "").trim();
    const whatsapp = String(datos.get("whatsapp") ?? "").trim();

    // No basta con `required`: los espacios tampoco son datos válidos.
    if (!nombres || !apellidos || !estado || !asesor) {
      setError("Completa tu nombre, apellidos, estado y asesor.");
      return;
    }

    if (!/^\d{10}$/.test(whatsapp)) {
      setError("Escribe un WhatsApp válido de 10 dígitos.");
      return;
    }

    if (tipoParticipante !== "vendedora" && tipoParticipante !== "promotora") {
      setError("Indica si eres vendedora o promotora.");
      return;
    }

    if (!foto) {
      setError(
        "Debes agregar una fotografía de tu rostro."
      );
      return;
    }

    if (!TIPOS.includes(foto.type) || foto.size > MAX_ARCHIVO || foto.size === 0) {
      setError("La fotografía debe ser JPG, PNG o WebP y pesar entre 1 byte y 5 MB.");
      return;
    }

    if (!cuentaElegida) {
      setError(
        "Selecciona la cuenta a la que realizaste tu transferencia."
      );
      return;
    }

    if (!comprobante) {
      setError(
        "Debes adjuntar tu comprobante de transferencia."
      );
      return;
    }

    if (!TIPOS.includes(comprobante.type) || comprobante.size > MAX_ARCHIVO || comprobante.size === 0) {
      setError("El comprobante debe ser JPG, PNG o WebP y pesar entre 1 byte y 5 MB.");
      return;
    }

    if (!aceptaPrivacidad) {
      setError(
        "Debes aceptar el aviso de privacidad."
      );
      return;
    }

    // Todavía no enviamos información a Supabase.
    // El backend permanecerá cerrado hasta que
    // publiquemos el aviso definitivo y completemos
    // las pruebas de seguridad.

    setError(
      "El envío de inscripciones todavía no está disponible."
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
        <h1>Registro de participantes</h1>
        <p>Evento Anual AMOR 2026</p>
      </div>

      <form
        className="registro-formulario"
        onSubmit={enviarRegistro}
      >
        <p className="registro-obligatorios">
          Todos los campos son obligatorios, incluida la fotografía y el comprobante.
        </p>

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
                onChange={() => setTipoParticipante("promotora")}
                required
              />
              Promotora
            </label>
          </div>
        </fieldset>

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

          <SelectorAsesor />

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
              validarArchivo(e, setFoto)
            }
            style={{ display: "none" }}
          />

          <input
            aria-label="Fotografía de rostro desde galería"
            ref={galeriaRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            onChange={(e) =>
              validarArchivo(e, setFoto)
            }
            style={{ display: "none" }}
          />
        </div>

        <div className="amor-pagos">
          <div className="amor-pagos-titulo">
            <Landmark size={25} />

            <div>
              <h2>
                ¿Dónde realizar mi transferencia?
              </h2>
              <p>
                Selecciona una de las cuentas disponibles.
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
              Transfiere exactamente{" "}
              <strong>$300.00 MXN</strong> a una
              de las cuentas indicadas.
              Conserva tu comprobante para
              adjuntarlo a tu inscripción.
              El pago será revisado por
              administración.
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
            !REGISTROS_HABILITADOS
          }
          style={{
            opacity:
              aceptaPrivacidad &&
              REGISTROS_HABILITADOS
                ? 1
                : 0.55,
            cursor:
              aceptaPrivacidad &&
              REGISTROS_HABILITADOS
                ? "pointer"
                : "not-allowed",
          }}
        >
          {REGISTROS_HABILITADOS ? (
            "Enviar mi registro"
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

        {!REGISTROS_HABILITADOS && (
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
