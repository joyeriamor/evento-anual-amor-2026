
import { useState, type FormEvent } from "react";
import {
  ArrowLeft,
  LockKeyhole,
  LogIn,
  ShieldCheck,
} from "lucide-react";
import { supabase } from "../lib/supabase";
import { verificarRolAccesoDetallado, type RolPantalla } from "../lib/verificarRolAcceso";

type Props = {
  onVolver: () => void;
  onAcceso: (rol: RolPantalla) => void;
};

export default function LoginAdmin({
  onVolver,
  onAcceso,
}: Props) {
  const [usuario, setUsuario] = useState("");
  const [password, setPassword] = useState("");
  const [cargando, setCargando] = useState(false);
  const [error, setError] = useState("");

  async function iniciarSesion(
    event: FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();

    if (cargando) return;

    setError("");
    setCargando(true);

    try {
      let accessToken = '';
      if (usuario.trim().includes('@')) {
        // Compatibilidad para administradores antiguos hasta que se asignen usuario.
        const { data, error: authError } = await supabase.auth.signInWithPassword({
          email: usuario.trim(), password,
        });
        if (authError || !data.session) {
          setError('Usuario o contraseña incorrectos.');
          return;
        }
        accessToken = data.session.access_token;
      } else {
        // El empleado nunca necesita un correo para ingresar.
        const { data, error: fallo } = await supabase.functions.invoke('iniciar-sesion-usuario', {
          body: { usuario: usuario.trim(), password },
        });
        if (fallo || !data?.ok || !data?.access_token || !data?.refresh_token) {
          setError('Usuario o contraseña incorrectos.');
          return;
        }
        const { data: inicio, error: errorSesion } = await supabase.auth.setSession({
          access_token: data.access_token, refresh_token: data.refresh_token,
        });
        if (errorSesion || !inicio.session) {
          setError('No se pudo abrir la sesión. Inténtalo de nuevo.');
          return;
        }
        accessToken = inicio.session.access_token;
      }

      const validacion = await verificarRolAccesoDetallado(accessToken);
      if (!validacion.rol) {
        await supabase.auth.signOut();
        setError(validacion.error || "No se pudo autorizar la cuenta.");
        return;
      }

      setPassword("");
      onAcceso(validacion.rol);
    } catch {
      await supabase.auth.signOut();

      setError(
        "Ocurrió un error al iniciar sesión."
      );
    } finally {
      setCargando(false);
    }
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: 20,
        background:
          "linear-gradient(135deg, #fff5f8, #ffe5ee)",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: 420,
          padding: 32,
          borderRadius: 22,
          background: "#ffffff",
          boxShadow:
            "0 18px 50px rgba(135, 40, 75, 0.12)",
        }}
      >
        <button
          type="button"
          onClick={onVolver}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            border: 0,
            background: "transparent",
            color: "#a33460",
            cursor: "pointer",
          }}
        >
          <ArrowLeft size={18} />
          Volver al inicio
        </button>

        <div
          style={{
            textAlign: "center",
            margin: "30px 0",
          }}
        >
          <ShieldCheck
            size={48}
            color="#b53869"
          />

          <h1
            style={{
              color: "#a33460",
              fontSize: 27,
              marginBottom: 8,
            }}
          >
            Acceso AMOR
          </h1>

          <p style={{ color: "#82727a" }}>
            Acceso para administración, validación, recepción y control de entradas
          </p>
        </div>

        <form onSubmit={iniciarSesion}>
          <label style={estiloLabel}>
            Nombre de usuario
            <input
              type="text"
              value={usuario}
              onChange={(e) =>
                setUsuario(e.target.value)
              }
              autoComplete="username"
              required
              style={estiloInput}
              placeholder="Ej. recepcion01"
            />
          </label>

          <label style={estiloLabel}>
            Contraseña
            <input
              type="password"
              value={password}
              onChange={(e) =>
                setPassword(e.target.value)
              }
              autoComplete="current-password"
              required
              style={estiloInput}
              placeholder="Tu contraseña"
            />
          </label>

          {error && (
            <p
              role="alert"
              style={{
                color: "#b42345",
                fontSize: 14,
                lineHeight: 1.5,
              }}
            >
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={cargando}
            style={{
              width: "100%",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: 10,
              border: 0,
              borderRadius: 12,
              padding: 15,
              marginTop: 20,
              background: "#a33460",
              color: "white",
              fontWeight: 700,
              cursor: cargando
                ? "wait"
                : "pointer",
            }}
          >
            {cargando ? (
              <LockKeyhole size={18} />
            ) : (
              <LogIn size={18} />
            )}

            {cargando
              ? "Verificando acceso..."
              : "Iniciar sesión"}
          </button>
        </form>

        <p
          style={{
            marginTop: 24,
            textAlign: "center",
            color: "#9b8b92",
            fontSize: 12,
          }}
        >
          FIESTAANUAL26 · Joyería AMOR
        </p>
      </section>
    </main>
  );
}

const estiloLabel = {
  display: "block",
  marginBottom: 18,
  fontWeight: 600,
  color: "#55424b",
};

const estiloInput = {
  display: "block",
  boxSizing: "border-box" as const,
  width: "100%",
  marginTop: 8,
  padding: 13,
  border: "1px solid #e9cbd7",
  borderRadius: 10,
  fontSize: 15,
};
