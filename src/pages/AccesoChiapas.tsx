import { useCallback, useEffect, useState } from "react";
import LoginAdmin from "./LoginAdmin";
import ControlAcceso from "./ControlAcceso";
import { supabase } from "../lib/supabase";
import { verificarRolAcceso } from "../lib/verificarRolAcceso";

const EVENTO_CHIAPAS = "3dc92160-79af-4bf7-b770-263038e88900";

type Estado = "verificando" | "sin_sesion" | "sin_permiso" | "autorizado";

export default function AccesoChiapas() {
  const [estado, setEstado] = useState<Estado>("verificando");
  const [error, setError] = useState("");

  const verificar = useCallback(async () => {
    setEstado("verificando");
    setError("");

    try {
      const { data: usuario, error: errorUsuario } =
        await supabase.auth.getUser();

      if (errorUsuario || !usuario.user) {
        setEstado("sin_sesion");
        return;
      }

      const { data: sesion } = await supabase.auth.getSession();

      if (!sesion.session) {
        setEstado("sin_sesion");
        return;
      }

      const rol = await verificarRolAcceso(
        sesion.session.access_token
      );

      if (rol !== "admin" && rol !== "acceso") {
        setEstado("sin_permiso");
        return;
      }

      const { data: permiso, error: errorPermiso } =
        await supabase
          .from("usuarios_eventos")
          .select("evento_id")
          .eq("usuario_id", usuario.user.id)
          .eq("evento_id", EVENTO_CHIAPAS)
          .eq("activo", true)
          .maybeSingle();

      if (errorPermiso) {
        setError("No se pudieron verificar los permisos.");
        setEstado("sin_permiso");
        return;
      }

      setEstado(permiso ? "autorizado" : "sin_permiso");
    } catch {
      setError("No se pudo verificar la autorización.");
      setEstado("sin_permiso");
    }
  }, []);

  useEffect(() => {
    void verificar();
  }, [verificar]);

  const volver = () => {
    window.location.assign(
      `${import.meta.env.BASE_URL}chiapas`
    );
  };

  const cerrarSesion = async () => {
    await supabase.auth.signOut();
    setEstado("sin_sesion");
  };

  if (estado === "verificando") {
    return <main style={{padding: 32}}>
      Verificando permisos para Chiapas...
    </main>;
  }

  if (estado === "sin_sesion") {
    return (
      <LoginAdmin
        onVolver={volver}
        onAcceso={() => { void verificar(); }}
      />
    );
  }

  if (estado === "sin_permiso") {
    return <main style={{padding: 32, maxWidth: 650, margin: "auto"}}>
      <h1>Acceso restringido · Chiapas</h1>
      <p>
        Tu cuenta no tiene autorización para operar
        el control de acceso de este evento.
      </p>
      {error && <p role="alert">{error}</p>}
      <button onClick={() => void cerrarSesion()}>
        Cerrar sesión
      </button>
      <button onClick={volver}>
        Volver a Chiapas
      </button>
    </main>;
  }

  return <main style={{background:"#fff6f9",minHeight:"100vh",padding:18}}>
    <h1>Control de acceso · Chiapas</h1>
    <button onClick={() => void cerrarSesion()}>
      Cerrar sesión
    </button>
    <ControlAcceso eventoId={EVENTO_CHIAPAS} />
  </main>;
}