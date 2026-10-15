
import { useEffect, useState } from "react";
import { supabase } from "../lib/supabase";

type Asesor = {
  id: string;
  nombre: string;
};

export default function PruebaSupabase() {
  const [asesores, setAsesores] = useState<Asesor[]>([]);
  const [mensaje, setMensaje] = useState("Conectando con Supabase...");

  useEffect(() => {
    async function cargar() {
      const { data, error } = await supabase
        .from("asesores")
        .select("id, nombre")
        .eq("activo", true)
        .order("nombre");

      if (error) {
        setMensaje(`Error: ${error.message}`);
        return;
      }

      setAsesores(data ?? []);
      setMensaje("Conexión correcta con Supabase");
    }

    void cargar();
  }, []);

  return (
    <div style={{ padding: 24 }}>
      <h2>Prueba de Supabase</h2>
      <p>{mensaje}</p>

      {asesores.map((asesor) => (
        <p key={asesor.id}>✓ {asesor.nombre}</p>
      ))}
    </div>
  );
}
