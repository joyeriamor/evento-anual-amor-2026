import { useEffect, useRef, useState } from "react";

type TurnstileAPI = {
  render: (
    element: HTMLElement,
    options: {
      sitekey: string;
      callback: (token: string) => void;
      "expired-callback": () => void;
      "error-callback": () => void;
    }
  ) => string;
  remove: (id: string) => void;
};

type VentanaTurnstile = Window & { turnstile?: TurnstileAPI };

export default function TurnstileRegistro({
  onToken,
}: {
  onToken: (token: string) => void;
}) {
  const contenedor = useRef<HTMLDivElement>(null);
  const onTokenRef = useRef(onToken);
  const widgetId = useRef<string | null>(null);
  const [error, setError] = useState("");
  const sitekey = import.meta.env.VITE_TURNSTILE_SITE_KEY;

  useEffect(() => {
    onTokenRef.current = onToken;
  }, [onToken]);

  useEffect(() => {
    if (!sitekey) return;

    let vivo = true;
    const wnd = window as VentanaTurnstile;
    let reintentos = 0;
    let comprobacion: number | undefined;
    let script: HTMLScriptElement | null = null;

    // El script se comparte entre las pantallas. No eliminarlo al salir:
    // quitarlo mientras carga puede impedir que Turnstile aparezca al volver.
    function montar() {
      if (!vivo || !contenedor.current || widgetId.current || !wnd.turnstile) return;
      try {
        setError("");
        widgetId.current = wnd.turnstile.render(contenedor.current, {
          sitekey,
          callback: (token) => {
            if (vivo) {
              setError("");
              onTokenRef.current(token);
            }
          },
          "expired-callback": () => {
            if (vivo) onTokenRef.current("");
          },
          "error-callback": () => {
            if (!vivo) return;
            onTokenRef.current("");
            setError("No se pudo validar la seguridad. Actualiza la página.");
          },
        });
        if (comprobacion !== undefined) window.clearInterval(comprobacion);
      } catch {
        if (vivo) setError("No se pudo iniciar la verificación. Actualiza la página.");
      }
    }

    function errorCarga() {
      if (vivo) {
        onTokenRef.current("");
        setError("No se pudo cargar la verificación de seguridad.");
      }
    }

    if (!wnd.turnstile) {
      script = document.querySelector<HTMLScriptElement>(
        'script[data-registro-turnstile="1"]'
      );
      if (!script) {
        script = document.createElement("script");
        script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
        script.async = true;
        script.dataset.registroTurnstile = "1";
        document.head.appendChild(script);
      }
      script.addEventListener("load", montar);
      script.addEventListener("error", errorCarga);
    }

    montar();
    // Respaldo para navegación rápida o un script que terminó de cargar
    // antes de que el componente registrara el listener.
    if (!widgetId.current) {
      comprobacion = window.setInterval(() => {
        montar();
        reintentos += 1;
        if (widgetId.current || reintentos >= 50) {
          if (comprobacion !== undefined) window.clearInterval(comprobacion);
          if (reintentos >= 50 && !widgetId.current) errorCarga();
        }
      }, 200);
    }

    return () => {
      vivo = false;
      if (comprobacion !== undefined) window.clearInterval(comprobacion);
      script?.removeEventListener("load", montar);
      script?.removeEventListener("error", errorCarga);
      const id = widgetId.current;
      if (id && wnd.turnstile) wnd.turnstile.remove(id);
      widgetId.current = null;
      onTokenRef.current("");
      // Importante: el script compartido se conserva para futuras visitas.
    };
  }, [sitekey]);

  if (!sitekey) {
    return <p className="registro-error" role="alert">
      Falta configurar la clave pública de Turnstile para habilitar el registro.
    </p>;
  }

  return (
    <div className="registro-turnstile">
      <div ref={contenedor} />
      {error && <p className="registro-error" role="alert">{error}</p>}
    </div>
  );
}
