
import { useEffect, useState } from "react";

import {
  CalendarDays,
  MapPin,
  UserRoundPlus,
  ShieldCheck,
  Sparkles,
  LockKeyhole,
} from "lucide-react";

import Registro from "./pages/Registro";
import LoginAdmin from "./pages/LoginAdmin";
import PanelAdmin from "./pages/PanelAdmin";
import ControlAcceso from "./pages/ControlAcceso";
import PanelPersonal from "./pages/PanelPersonal";

import { supabase } from "./lib/supabase";
import { verificarRolAcceso } from "./lib/verificarRolAcceso";

import "./App.css";

type Pantalla = "inicio" | "registro" | "login" | "admin" | "acceso" | "validador" | "recepcion";

export default function App() {
  const [pantalla, setPantalla] =
    useState<Pantalla>("inicio");

  const [verificando, setVerificando] =
    useState(true);

  useEffect(() => {
    let vigente = true;

    async function verificarSesion() {
      try {
        const { data, error } =
          await supabase.auth.getSession();

        if (!vigente) return;

        if (error || !data.session) {
          setVerificando(false);
          return;
        }

        const rol = await verificarRolAcceso(data.session.access_token);
        if (!rol) {
          await supabase.auth.signOut();
          if (vigente) setPantalla("inicio");
        } else if (vigente) {
          setPantalla(rol);
        }
      } catch {
        await supabase.auth.signOut();
        if (vigente) setPantalla("inicio");
      } finally {
        if (vigente) setVerificando(false);
      }
    }

    void verificarSesion();

    return () => {
      vigente = false;
    };
  }, []);

  function volverInicio() {
    setPantalla("inicio");
  }

  if (verificando) {
    return (
      <div
        style={{
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#fff5f8",
          color: "#a33460",
          fontWeight: 600,
        }}
      >
        Verificando sesión...
      </div>
    );
  }

  if (pantalla === "login") {
    return (
      <LoginAdmin
        onVolver={volverInicio}
        onAcceso={(rol) => setPantalla(rol)}
      />
    );
  }

  if (pantalla === "acceso") {
    return <div style={{background:"#fff6f9",minHeight:"100vh",padding:18}}><button onClick={async()=>{await supabase.auth.signOut();setPantalla("inicio");}}>Cerrar sesión</button><ControlAcceso /></div>;
  }

  if (pantalla === "validador" || pantalla === "recepcion") {
    return <PanelPersonal rol={pantalla} onSalir={volverInicio} />;
  }

  if (pantalla === "admin") {
    return (
      <PanelAdmin
        onSalir={volverInicio}
      />
    );
  }

  return (
    <div className="app">
      <header className="encabezado">
        <div className="marca">
          <img
            src={`${import.meta.env.BASE_URL}amor-logo.png`}
            alt="Logo de AMOR"
          />

          <div>
            <strong>AMOR</strong>
            <small>Plataforma de eventos</small>
          </div>
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            flexWrap: "wrap",
          }}
        >
          <span className="etiqueta">
            FIESTAANUAL26
          </span>

          <button
            type="button"
            onClick={() => setPantalla("login")}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 7,
              border: "1px solid #e7c2d0",
              borderRadius: 10,
              padding: "9px 13px",
              background: "#ffffff",
              color: "#a33460",
              fontWeight: 600,
              cursor: "pointer",
              fontSize: 13,
            }}
          >
            <LockKeyhole size={16} />
            Administración
          </button>
        </div>
      </header>

      <main className="principal">
        {pantalla === "inicio" ? (
          <section className="tarjeta">
            <div className="distintivo">
              <Sparkles size={16} />
              UN EVENTO ESPECIAL
            </div>

            <img
              className="logo-principal"
              src={`${import.meta.env.BASE_URL}amor-logo.png`}
              alt="Logo de AMOR"
            />

            <p className="subtitulo">
              CELEBREMOS JUNTOS
            </p>

            <h1>
              Fiesta Anual <span>2026</span>
            </h1>

            <p className="descripcion">
              Un encuentro para celebrar nuestros
              logros, reconocer nuestro esfuerzo y
              compartir momentos inolvidables.
            </p>

            <div className="informacion">
              <div>
                <CalendarDays size={21} />
                <span>
                  Domingo 6 de diciembre de 2026
                </span>
              </div>

              <div>
                <MapPin size={21} />
                <span>
                  Salón RADEV'S 1, Minatitlán,
                  Veracruz
                </span>
              </div>
            </div>

            <button
              type="button"
              className="boton-principal"
              onClick={() =>
                setPantalla("registro")
              }
            >
              <UserRoundPlus size={20} />
              Registrarme al evento
            </button>

            <div className="seguridad">
              <ShieldCheck size={17} />
              Registro seguro de participantes
            </div>
          </section>
        ) : (
          <Registro onVolver={volverInicio} />
        )}
      </main>

      <footer>
        © 2026 AMOR · Plataforma de gestión
        de eventos
      </footer>
    </div>
  );
}
