import { invocarEvento } from '../lib/evento';

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type FormEvent,
} from "react";
import {
  Search,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  Users,
  AlertCircle,
  Eye,
} from "lucide-react";
import { supabase } from "../lib/supabase";
import DetalleParticipante from "./DetalleParticipante";
type Relacion<T> = T | T[] | null;
type Promotora = {
  nombres: string | null;
  apellidos: string | null;
  telefono_whatsapp: string | null;
  estado_residencia: string | null;
};
type Asesor = {
  nombre: string | null;
};
type Evento = {
  nombre: string | null;
  cuota_fija: number | null;
};
type Pago = {
  importe: number | null;
  estado: string | null;
  cuenta_destino: string | null;
};
type Participante = {
  id: string;
  folio: string | number | null;
  estado: string | null;
  exento_pago: boolean | null;
  created_at: string | null;
  evento_id: string | null;
  promotora: Relacion<Promotora>;
  asesor: Relacion<Asesor>;
  evento: Relacion<Evento>;
  pago: Relacion<Pago>;
};
type RespuestaParticipantes = {
  ok: boolean;
  mensaje?: string;
  pagina?: number;
  limite?: number;
  total?: number;
  participantes?: Participante[];
};
const LIMITE = 20;
const botonBase: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 7,
  padding: "10px 14px",
  borderRadius: 10,
  cursor: "pointer",
  fontSize: 14,
};
const celda: CSSProperties = {
  padding: 13,
  verticalAlign: "middle",
};
function primeraRelacion<T>(
  relacion: Relacion<T>
): T | null {
  if (Array.isArray(relacion)) {
    return relacion[0] ?? null;
  }
  return relacion ?? null;
}
function mostrarTexto(
  valor: string | number | null | undefined
): string {
  if (
    valor === null ||
    valor === undefined ||
    valor === ""
  ) {
    return "—";
  }
  return String(valor);
}
function formatearFecha(
  valor: string | null
): string {
  if (!valor) return "—";
  const fecha = new Date(valor);
  if (Number.isNaN(fecha.getTime())) {
    return "—";
  }
  return new Intl.DateTimeFormat("es-MX", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "America/Mexico_City",
  }).format(fecha);
}
function formatearDinero(
  valor: number | null | undefined
): string {
  if (
    valor === null ||
    valor === undefined
  ) {
    return "—";
  }
  return new Intl.NumberFormat("es-MX", {
    style: "currency",
    currency: "MXN",
  }).format(valor);
}
function estiloEstado(
  estado: string | null
): CSSProperties {
  const normalizado = (
    estado ?? ""
  ).toLowerCase();
  if (
    normalizado.includes("aprob") ||
    normalizado.includes("valid") ||
    normalizado.includes("confirm")
  ) {
    return {
      color: "#166534",
      background: "#dcfce7",
    };
  }
  if (
    normalizado.includes("rechaz") ||
    normalizado.includes("cancel")
  ) {
    return {
      color: "#991b1b",
      background: "#fee2e2",
    };
  }
  return {
    color: "#92400e",
    background: "#fef3c7",
  };
}
function EtiquetaEstado({
  estado,
}: {
  estado: string | null;
}) {
  return (
    <span
      style={{
        ...estiloEstado(estado),
        display: "inline-block",
        padding: "5px 10px",
        borderRadius: 20,
        fontSize: 12,
        fontWeight: 600,
        whiteSpace: "nowrap",
      }}
    >
      {mostrarTexto(estado)}
    </span>
  );
}
export default function ParticipantesAdmin() {
  const [participantes, setParticipantes] =
    useState<Participante[]>([]);
  const [busqueda, setBusqueda] =
    useState("");
  const [filtro, setFiltro] =
    useState("");
  const [pagina, setPagina] =
    useState(1);
  const [total, setTotal] =
    useState(0);
  const [cargando, setCargando] =
    useState(false);
  const [error, setError] =
    useState("");
  // NUEVO: inscripción cuyo detalle se abrirá.
  const [
    registroSeleccionado,
    setRegistroSeleccionado,
  ] = useState<string | null>(null);
  // Evita que una consulta antigua sobrescriba
  // los resultados de una búsqueda más reciente.
  const solicitudActual = useRef(0);
  const consultar = useCallback(
    async (
      paginaActual: number,
      textoBusqueda: string
    ) => {
      const solicitud = ++solicitudActual.current;
      setCargando(true);
      setError("");
      try {
        const {
          data: sesion,
          error: errorSesion,
        } = await supabase.auth.getSession();
        if (
          errorSesion ||
          !sesion.session
        ) {
          throw new Error(
            "Tu sesión terminó. Cierra sesión y vuelve a entrar."
          );
        }
        const {
          data,
          error: errorFuncion,
        } = await invocarEvento(
          "listar-participantes",
          {
            method: "POST",
            headers: {
              Authorization:
                `Bearer ${sesion.session.access_token}`,
            },
            body: {
              pagina: paginaActual,
              limite: LIMITE,
              busqueda: textoBusqueda,
            },
          }
        );
        if (errorFuncion) {
          let mensaje = errorFuncion.message;
          const contexto = (
            errorFuncion as {
              context?: Response;
            }
          ).context;
          if (contexto instanceof Response) {
            try {
              const detalle =
                await contexto.clone().json();
              if (
                typeof detalle?.mensaje === "string"
              ) {
                mensaje = detalle.mensaje;
              }
            } catch {
              // Conservamos el error original.
            }
          }
          throw new Error(mensaje);
        }
        const respuesta =
          data as RespuestaParticipantes;
        if (
          !respuesta ||
          respuesta.ok !== true
        ) {
          throw new Error(
            respuesta?.mensaje ??
              "No se pudieron consultar los participantes."
          );
        }
        if (
          solicitud !== solicitudActual.current
        ) {
          return;
        }
        setParticipantes(
          Array.isArray(respuesta.participantes)
            ? respuesta.participantes
            : []
        );
        setTotal(
          typeof respuesta.total === "number"
            ? respuesta.total
            : 0
        );
      } catch (err) {
        if (
          solicitud !== solicitudActual.current
        ) {
          return;
        }
        setParticipantes([]);
        setTotal(0);
        setError(
          err instanceof Error
            ? err.message
            : "Ocurrió un error inesperado."
        );
      } finally {
        if (
          solicitud === solicitudActual.current
        ) {
          setCargando(false);
        }
      }
    },
    []
  );
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- Sincroniza una consulta externa y su estado de carga.
    void consultar(pagina, filtro);
    return () => {
      solicitudActual.current += 1;
    };
  }, [pagina, filtro, consultar]);
  const totalPaginas = Math.max(
    1,
    Math.ceil(total / LIMITE)
  );
  function buscar(
    evento: FormEvent<HTMLFormElement>
  ) {
    evento.preventDefault();
    const nuevoFiltro = busqueda.trim();
    if (
      pagina === 1 &&
      filtro === nuevoFiltro
    ) {
      void consultar(1, nuevoFiltro);
      return;
    }
    setPagina(1);
    setFiltro(nuevoFiltro);
  }
  function limpiarBusqueda() {
    setBusqueda("");
    if (
      pagina === 1 &&
      filtro === ""
    ) {
      void consultar(1, "");
      return;
    }
    setPagina(1);
    setFiltro("");
  }
  return (
    <section
      style={{
        marginTop: 28,
        padding: 24,
        background: "#fff",
        border: "1px solid #f0d5df",
        borderRadius: 18,
      }}
    >
      {/* ENCABEZADO */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          flexWrap: "wrap",
          gap: 16,
          marginBottom: 22,
        }}
      >
        <div>
          <h2
            style={{
              margin: "0 0 8px",
              color: "#a33460",
              display: "flex",
              alignItems: "center",
              gap: 10,
            }}
          >
            <Users size={25} />
            Gestión de participantes
          </h2>
          <p
            style={{
              margin: 0,
              color: "#806e76",
              fontSize: 14,
            }}
          >
            Consulta de inscripciones y
            revisión privada de comprobantes.
          </p>
        </div>
        <button
          type="button"
          onClick={() =>
            void consultar(pagina, filtro)
          }
          disabled={cargando}
          style={{
            ...botonBase,
            border: "1px solid #e5bdcc",
            background: "#fff",
            color: "#a33460",
          }}
        >
          <RefreshCw size={17} />
          {cargando
            ? "Consultando..."
            : "Actualizar"}
        </button>
      </div>
      {/* RESUMEN */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns:
            "repeat(auto-fit, minmax(180px, 1fr))",
          gap: 14,
          marginBottom: 22,
        }}
      >
        <div
          style={{
            background: "#fff6f9",
            padding: 18,
            borderRadius: 12,
          }}
        >
          <span
            style={{
              display: "block",
              color: "#806e76",
              fontSize: 13,
            }}
          >
            Registros encontrados
          </span>
          <strong
            style={{
              fontSize: 29,
              color: "#a33460",
            }}
          >
            {total}
          </strong>
        </div>
        <div
          style={{
            background: "#fff6f9",
            padding: 18,
            borderRadius: 12,
          }}
        >
          <span
            style={{
              display: "block",
              color: "#806e76",
              fontSize: 13,
            }}
          >
            Página actual
          </span>
          <strong
            style={{
              fontSize: 29,
              color: "#a33460",
            }}
          >
            {pagina} / {totalPaginas}
          </strong>
        </div>
      </div>
      {/* BÚSQUEDA */}
      <form
        onSubmit={buscar}
        style={{
          display: "flex",
          gap: 10,
          flexWrap: "wrap",
          marginBottom: 20,
        }}
      >
        <input
          type="search"
          value={busqueda}
          onChange={(e) =>
            setBusqueda(e.target.value)
          }
          placeholder="Nombre, apellido o WhatsApp"
          maxLength={100}
          style={{
            flex: "1 1 260px",
            minWidth: 0,
            padding: "12px 14px",
            border: "1px solid #e5bdcc",
            borderRadius: 10,
            fontSize: 14,
          }}
        />
        <button
          type="submit"
          disabled={cargando}
          style={{
            ...botonBase,
            border: 0,
            background: "#a33460",
            color: "#fff",
          }}
        >
          <Search size={17} />
          Buscar
        </button>
        {filtro && (
          <button
            type="button"
            onClick={limpiarBusqueda}
            disabled={cargando}
            style={{
              ...botonBase,
              border: "1px solid #e5bdcc",
              background: "#fff",
              color: "#a33460",
            }}
          >
            Limpiar
          </button>
        )}
      </form>
      {/* ERRORES */}
      {error && (
        <div
          role="alert"
          style={{
            display: "flex",
            alignItems: "center",
            gap: 10,
            padding: 15,
            marginBottom: 18,
            background: "#fef2f2",
            color: "#991b1b",
            borderRadius: 10,
          }}
        >
          <AlertCircle size={20} />
          {error}
        </div>
      )}
      {/* TABLA */}
      <div
        style={{
          overflowX: "auto",
          border: "1px solid #f0d5df",
          borderRadius: 12,
        }}
      >
        <table
          style={{
            width: "100%",
            borderCollapse: "collapse",
            minWidth: 1080,
            textAlign: "left",
          }}
        >
          <thead
            style={{
              background: "#fff0f5",
              color: "#87314f",
            }}
          >
            <tr>
              {[
                "Folio",
                "Participante",
                "WhatsApp",
                "Asesor",
                "Evento",
                "Inscripción",
                "Pago",
                "Importe",
                "Fecha",
                "Acciones",
              ].map((titulo) => (
                <th
                  key={titulo}
                  scope="col"
                  style={{
                    padding: 13,
                    fontSize: 13,
                    whiteSpace: "nowrap",
                  }}
                >
                  {titulo}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {participantes.map(
              (participante) => {
                const promotora =
                  primeraRelacion(
                    participante.promotora
                  );
                const asesor =
                  primeraRelacion(
                    participante.asesor
                  );
                const evento =
                  primeraRelacion(
                    participante.evento
                  );
                const pago =
                  primeraRelacion(
                    participante.pago
                  );
                const nombreCompleto = [
                  promotora?.nombres,
                  promotora?.apellidos,
                ]
                  .filter(Boolean)
                  .join(" ");
                return (
                  <tr
                    key={participante.id}
                    style={{
                      borderTop:
                        "1px solid #f5e3ea",
                    }}
                  >
                    <td style={celda}>
                      {mostrarTexto(
                        participante.folio
                      )}
                    </td>
                    <td
                      style={{
                        ...celda,
                        fontWeight: 600,
                      }}
                    >
                      {nombreCompleto || "—"}
                    </td>
                    <td style={celda}>
                      {mostrarTexto(
                        promotora
                          ?.telefono_whatsapp
                      )}
                    </td>
                    <td style={celda}>
                      {mostrarTexto(
                        asesor?.nombre
                      )}
                    </td>
                    <td style={celda}>
                      {mostrarTexto(
                        evento?.nombre
                      )}
                    </td>
                    <td style={celda}>
                      <EtiquetaEstado
                        estado={
                          participante.estado
                        }
                      />
                    </td>
                    <td style={celda}>
                      {participante.exento_pago ? (
                        "Exento"
                      ) : (
                        <EtiquetaEstado
                          estado={
                            pago?.estado ?? null
                          }
                        />
                      )}
                    </td>
                    <td style={celda}>
                      {participante.exento_pago
                        ? "Exento"
                        : formatearDinero(
                            pago?.importe
                          )}
                    </td>
                    <td
                      style={{
                        ...celda,
                        whiteSpace: "nowrap",
                      }}
                    >
                      {formatearFecha(
                        participante.created_at
                      )}
                    </td>
                    {/* NUEVA COLUMNA */}
                    <td style={celda}>
                      <button
                        type="button"
                        onClick={() =>
                          setRegistroSeleccionado(
                            participante.id
                          )
                        }
                        style={{
                          ...botonBase,
                          border:
                            "1px solid #e5bdcc",
                          background: "#fff6f9",
                          color: "#a33460",
                          whiteSpace: "nowrap",
                        }}
                      >
                        <Eye size={17} />
                        Ver detalle
                      </button>
                    </td>
                  </tr>
                );
              }
            )}
          </tbody>
        </table>
        {/* SIN REGISTROS */}
        {!cargando &&
          !error &&
          participantes.length === 0 && (
            <div
              style={{
                textAlign: "center",
                padding: "50px 20px",
                color: "#806e76",
              }}
            >
              <Users
                size={42}
                color="#d8a4b8"
              />
              <h3
                style={{
                  color: "#a33460",
                }}
              >
                No hay participantes
              </h3>
              <p>
                {filtro
                  ? "No encontramos inscripciones con esa búsqueda."
                  : "Todavía no hay inscripciones registradas."}
              </p>
            </div>
          )}
        {cargando && (
          <div
            role="status"
            style={{
              padding: 30,
              textAlign: "center",
              color: "#806e76",
            }}
          >
            Consultando participantes...
          </div>
        )}
      </div>
      {/* PAGINACIÓN */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent:
            "space-between",
          gap: 12,
          flexWrap: "wrap",
          marginTop: 20,
        }}
      >
        <span
          style={{
            fontSize: 13,
            color: "#806e76",
          }}
        >
          {total} registro(s) encontrados
        </span>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
          }}
        >
          <button
            type="button"
            onClick={() =>
              setPagina((actual) =>
                Math.max(1, actual - 1)
              )
            }
            disabled={
              cargando || pagina <= 1
            }
            style={{
              ...botonBase,
              border:
                "1px solid #e5bdcc",
              background: "#fff",
              color: "#a33460",
            }}
          >
            <ChevronLeft size={17} />
            Anterior
          </button>
          <span
            style={{
              fontSize: 13,
              color: "#806e76",
            }}
          >
            {pagina} de {totalPaginas}
          </span>
          <button
            type="button"
            onClick={() =>
              setPagina((actual) =>
                Math.min(
                  totalPaginas,
                  actual + 1
                )
              )
            }
            disabled={
              cargando ||
              pagina >= totalPaginas
            }
            style={{
              ...botonBase,
              border:
                "1px solid #e5bdcc",
              background: "#fff",
              color: "#a33460",
            }}
          >
            Siguiente
            <ChevronRight size={17} />
          </button>
        </div>
      </div>
      {/* VENTANA DE DETALLE */}
      {registroSeleccionado && (
        <DetalleParticipante
          key={registroSeleccionado}
          registroId={registroSeleccionado}
          onCerrar={() => {
            setRegistroSeleccionado(null);
            void consultar(pagina, filtro);
          }}
          onPagoActualizado={() => {
            void consultar(pagina, filtro);
          }}
        />
      )}
    </section>
  );
}
