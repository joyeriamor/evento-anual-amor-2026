
import { useEffect, useRef, useState } from "react";
import { supabase } from "../lib/supabase";

declare global {
  interface Window {
    turnstile?: {
      render: (
        container: HTMLElement,
        options: {
          sitekey: string;
          callback: (token: string) => void;
          "expired-callback": () => void;
          "error-callback": () => void;
        }
      ) => string;
      remove: (widgetId: string) => void;
    };
  }
}

const SITE_KEY = import.meta.env.VITE_TURNSTILE_SITE_KEY;

export default function PruebaTurnstile() {
  const contenedor = useRef<HTMLDivElement>(null);
  const widgetId = useRef<string | null>(null);

  const [token, setToken] = useState("");
  const [mensaje, setMensaje] = useState(SITE_KEY ? "" : "Falta VITE_TURNSTILE_SITE_KEY en .env.local");
  const [cargando, setCargando] = useState(false);

  useEffect(() => {
    if (!SITE_KEY) {
      return;
    }

    let cancelado = false;
    let intentos = 0;

    const iniciar = () => {
      if (
        cancelado ||
        widgetId.current ||
        !contenedor.current ||
        !window.turnstile
      ) {
        return;
      }

      widgetId.current = window.turnstile.render(
        contenedor.current,
        {
          sitekey: SITE_KEY,
          callback: setToken,
          "expired-callback": () => setToken(""),
          "error-callback": () => {
            setToken("");
            setMensaje("No se pudo completar Turnstile.");
          },
        }
      );
    };

    const script = document.createElement("script");
    script.src =
      "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
    script.async = true;
    script.onload = iniciar;
    script.onerror = () =>
      setMensaje("No se pudo cargar Cloudflare Turnstile.");

    document.head.appendChild(script);

    const intervalo = setInterval(() => {
      iniciar();
      intentos++;

      if (widgetId.current || intentos >= 30) {
        clearInterval(intervalo);
      }
    }, 300);

    return () => {
      cancelado = true;
      clearInterval(intervalo);

      if (widgetId.current && window.turnstile) {
        window.turnstile.remove(widgetId.current);
        widgetId.current = null;
      }

      script.remove();
    };
  }, []);

  async function verificar() {
    if (!token) {
      setMensaje("Primero completa la verificación.");
      return;
    }

    setCargando(true);
    setMensaje("Verificando con Supabase...");

    try {
      const { data, error } = await supabase.functions.invoke(
        "registrar-participante",
        {
          body: {
            accion: "verificar-turnstile",
            token,
          },
        }
      );

      if (error) {
        const detalle = await error.context
          ?.json?.()
          .catch(() => null);

        setMensaje(detalle?.mensaje ?? error.message);
      } else {
        setMensaje(JSON.stringify(data, null, 2));
      }
    } catch (error) {
      setMensaje(
        error instanceof Error ? error.message : "Error desconocido"
      );
    } finally {
      setToken("");
      setCargando(false);
    }
  }

  return (
    <main
      style={{
        maxWidth: 550,
        margin: "40px auto",
        padding: 24,
        fontFamily: "Arial, sans-serif",
      }}
    >
      <h1>Seguridad AMOR 2026</h1>

      <p>
        Prueba de Cloudflare Turnstile con Supabase.
        No guarda inscripciones.
      </p>

      <div ref={contenedor} style={{ margin: "25px 0" }} />

      <button
        type="button"
        onClick={verificar}
        disabled={!token || cargando}
        style={{
          padding: "12px 22px",
          background: "#c2185b",
          color: "white",
          border: 0,
          borderRadius: 8,
          cursor: "pointer",
        }}
      >
        {cargando ? "Verificando..." : "Verificar seguridad"}
      </button>

      {mensaje && (
        <pre
          style={{
            marginTop: 20,
            padding: 15,
            background: "#f5f5f5",
            whiteSpace: "pre-wrap",
            overflowWrap: "anywhere",
          }}
        >
          {mensaje}
        </pre>
      )}
    </main>
  );
}
