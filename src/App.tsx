import { EVENTOS as CONFIGURACION_EVENTOS } from "./config/eventos";
import { esChiapas, eventoActual } from './lib/evento';

import { useEffect, useState } from "react";

import {
  CalendarDays,
  MapPin,
  Clock3,
  UserRoundPlus,
  ShieldCheck,
  Sparkles,
  LockKeyhole,
} from "lucide-react";

import Registro from "./pages/Registro";
import LoginAdmin from "./pages/LoginAdmin";
import PanelAdmin from "./pages/PanelAdmin";
import ControlAcceso from "./pages/ControlAcceso";
import AccesoChiapas from "./pages/AccesoChiapas";
import PanelPersonal from "./pages/PanelPersonal";

import { supabase } from "./lib/supabase";
import { verificarRolAcceso } from "./lib/verificarRolAcceso";

import "./App.css";

type Pantalla = "inicio" | "registro" | "login" | "admin" | "acceso" | "validador" | "recepcion";

export default function App() {
  const rutaActual = window.location.pathname.replace(/\/+$/, "");

  if (rutaActual.endsWith("/chiapas/acceso")) {
    return <AccesoChiapas />;
  }

  return <AppPrincipal />;
}

function AppPrincipal() {



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
            <strong>JOYERIA_AMOR</strong>
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
            EVENTO_ANUAL26
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

      <nav aria-label="Seleccionar evento" style={{ padding: 16, textAlign: 'center' }}>
        <a href={import.meta.env.BASE_URL}>RADEV'S · Minatitlán</a> · <a href={`${import.meta.env.BASE_URL}chiapas`}>Chiapas</a>
        <p><strong>Operando: {eventoActual.nombre}</strong></p>
      </nav>
      <main className="principal">
        {pantalla === "inicio" ? (
          esChiapas ? <PaginaChiapas /> : <section className="tarjeta">
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
              Evento Anual <span>2026</span>
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

              <div>
                <Clock3 size={21} />
                <span>Recepción: 1:00 p.m.</span>
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
          <Registro evento={esChiapas ? "chiapas" : undefined} onVolver={volverInicio} />
        )}
      </main>

      <footer>
        © 2026 AMOR · Plataforma de gestión
        de eventos
      </footer>
    </div>
  );
}


function PaginaChiapas() {
  const [mostrarRegistro, setMostrarRegistro] = useState(false);

  if (mostrarRegistro) {
    return (
      <Registro
        evento="chiapas"
        onVolver={() => setMostrarRegistro(false)}
      />
    );
  }
  return (
    <main style={{
      minHeight: "100vh",
      background: "#fff5f8",
      display: "grid",
      placeItems: "center",
      padding: 24,
      fontFamily: "Arial, sans-serif",
      color: "#653d50"
    }}>
      <section style={{
        background: "white",
        padding: 32,
        borderRadius: 20,
        maxWidth: 570,
        width: "100%",
        textAlign: "center",
        boxShadow: "0 8px 32px #a3346020"
      }}>
        <img
          src={`${import.meta.env.BASE_URL}amor-logo.png`}
          alt="Joyería Amor de los Dos"
          style={{ maxWidth: 150, marginBottom: 20 }}
        />
        <h1 style={{ color: "#a33460" }}>
          Fiesta Anual AMOR 2026
        </h1>
        <h2>Chiapas</h2>
        <p><strong>Tuxtla Gutiérrez, Chiapas</strong></p>
        <p>Sábado 19 de diciembre de 2026</p>
        <p><strong>{CONFIGURACION_EVENTOS.chiapas.sede}</strong></p>
        <p>{CONFIGURACION_EVENTOS.chiapas.horario}</p>
        <p style={{
          marginTop: 24,
          padding: 14,
          background: "#fff0f5",
          borderRadius: 10
        }}>
          {CONFIGURACION_EVENTOS.chiapas.inscripcionesHabilitadas
            ? "Inscripciones abiertas · Cupo de 500 participantes"
            : "Las inscripciones para Chiapas todavía no están habilitadas."}
        </p>
        <button
          type="button"
          onClick={() => setMostrarRegistro(true)}
          style={{
            background: "#a33460",
            color: "white",
            border: "none",
            padding: "12px 20px",
            borderRadius: 10,
            cursor: "pointer",
            marginTop: 14
          }}
        >
          Registrarme en Chiapas
        </button>
      </section>
    </main>
  );
}
