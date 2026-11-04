import ContenidoAvisoPrivacidad from "../components/ContenidoAvisoPrivacidad";
import "./Privacidad.css";

export default function Privacidad() {
  return (
    <div className="pagina-privacidad">
      <header className="privacidad-marca">
        <img src={`${import.meta.env.BASE_URL}amor-logo.png`} alt="Joyería AMOR de los Dos" />
        <div><strong>JOYERÍA AMOR DE LOS DOS</strong><p>Plataforma de eventos</p></div>
      </header>
      <main className="privacidad-documento">
        <p className="privacidad-etiqueta">FIESTA ANUAL AMOR 2026</p>
        <h1>Aviso de privacidad</h1>
        <p className="privacidad-intro">Consulta pública para los registros de Minatitlán y Chiapas.</p>
        <article aria-label="Texto completo del aviso de privacidad">
          <ContenidoAvisoPrivacidad />
        </article>
      </main>
      <footer>© 2026 AMOR · Plataforma de gestión de eventos</footer>
    </div>
  );
}
