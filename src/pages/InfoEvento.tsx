
import { useEffect, useState } from "react";
import { CalendarDays, MapPin, Wallet } from "lucide-react";
import { supabase } from "../lib/supabase";

type Evento = {
  id: string;
  nombre: string;
  descripcion: string | null;
  fecha_inicio: string;
  sede: string;
  cuota_fija: number;
};

export default function InfoEvento() {
  const [evento, setEvento] = useState<Evento | null>(null);
  const [cargando, setCargando] = useState(true);
  const [mensaje, setMensaje] = useState("");

  useEffect(() => {
    let activo = true;

    async function cargarEvento() {
      const { data, error } = await supabase
        .rpc("obtener_eventos_publicos");

      if (!activo) return;

      if (error) {
        setMensaje("No se pudo consultar la información del evento.");
      } else if (!data || data.length === 0) {
        setMensaje(
          "El evento todavía está en preparación. " +
          "La información pública estará disponible cuando se active."
        );
      } else {
        setEvento(data[0] as Evento);
      }

      setCargando(false);
    }

    void cargarEvento();

    return () => {
      activo = false;
    };
  }, []);

  if (cargando) {
    return <p>Consultando información del evento...</p>;
  }

  if (!evento) {
    return <p>{mensaje}</p>;
  }

  const fecha = new Intl.DateTimeFormat("es-MX", {
    timeZone: "America/Mexico_City",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date(evento.fecha_inicio));

  const cuota = new Intl.NumberFormat("es-MX", {
    style: "currency",
    currency: "MXN",
  }).format(evento.cuota_fija);

  return (
    <section
      style={{
        background: "#fff4f8",
        border: "1px solid #f6bfd2",
        borderRadius: 16,
        padding: 20,
        marginBottom: 24,
      }}
    >
      <h2 style={{ color: "#b31559" }}>{evento.nombre}</h2>

      <p>
        <CalendarDays size={18} style={{ verticalAlign: "middle" }} />
        {" "}{fecha}
      </p>

      <p>
        <MapPin size={18} style={{ verticalAlign: "middle" }} />
        {" "}{evento.sede}
      </p>

      <p>
        <Wallet size={18} style={{ verticalAlign: "middle" }} />
        {" "}Cuota: <strong>{cuota}</strong>
      </p>
    </section>
  );
}
