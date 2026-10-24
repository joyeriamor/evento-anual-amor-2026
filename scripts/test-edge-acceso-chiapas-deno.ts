import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const CHIAPAS = "3dc92160-79af-4bf7-b770-263038e88900";
const RADEVS = "43e67bda-d19d-4c0e-a639-e85f2d62f294";
const FUENTE = "supabase/functions/consultar-acceso-evento/index.ts";

// Legacy QR-handler test; shared guard has a separate executable matrix.
const original = (await Deno.readTextFile(FUENTE))
  .replace(/^import .*_shared\/evento[^\n]*\n/m, '')
  .replace(/serveEvento\(\{[^\n]+?\}, /, 'Deno.serve(');

const importOriginal =
  "import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';";

const inicioOriginal = "Deno.serve(async req=>{";

assert(original.includes(importOriginal));
assert(original.includes(inicioOriginal));
assert(/\}\);\s*$/.test(original));

const codigo = original
  .replace(
    importOriginal,
    "const createClient = (globalThis as typeof globalThis & { __crearClientePrueba: unknown }).__crearClientePrueba;"
  )
  .replace(
    inicioOriginal,
    "(globalThis as typeof globalThis & { __manejadorEdge: (req: Request) => Promise<Response> }).__manejadorEdge = async (req: Request) => {"
  )
  .replace(/\}\);\s*$/, "};");

Deno.env.set("SUPABASE_URL", "https://example.invalid");
Deno.env.set("SUPABASE_ANON_KEY", "anon-prueba");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "servicio-prueba");

let escenario: Record<string, unknown> = {};
let llamadasRPC: Array<Record<string, unknown>> = [];

function consulta(data: unknown) {
  return {
    select() { return this; },
    eq() { return this; },
    async single() { return { data, error: null }; },
    async maybeSingle() { return { data, error: null }; }
  };
}

(globalThis as typeof globalThis & { __crearClientePrueba: unknown }).__crearClientePrueba = (
  _url: string,
  clave: string
) => {
  if (clave === "servicio-prueba") {
    return {
      from(tabla: string) {
        if (tabla === "usuarios") {
          return consulta({
            rol: escenario.rol ?? "acceso",
            activo: escenario.activo ?? true
          });
        }

        if (tabla === "usuarios_eventos") {
          return consulta(
            escenario.permiso
              ? { usuario_id: "operador-prueba" }
              : null
          );
        }

        throw new Error("Lectura privada inesperada: " + tabla);
      }
    };
  }

  return {
    auth: {
      async getUser() {
        return {
          data: {
            user: escenario.sesion === false
              ? null
              : { id: "operador-prueba" }
          },
          error: escenario.sesion === false
            ? { message: "Sesion invalida" }
            : null
        };
      }
    },
    async rpc(nombre: string, parametros: Record<string, unknown>) {
      llamadasRPC.push({ nombre, parametros });
      return {
        data: { ok: false, estado: "qr_invalido" },
        error: null
      };
    }
  };
};

const temporal = await Deno.makeTempFile({ suffix: ".ts" });

try {
  await Deno.writeTextFile(temporal, codigo);

  await import(pathToFileURL(temporal).href);

  const manejar = (globalThis as typeof globalThis & { __manejadorEdge: (req: Request) => Promise<Response> }).__manejadorEdge;

  assert.equal(typeof manejar, "function");

  async function probar(
    nombre: string,
    opciones: Record<string, unknown>,
    evento: string,
    token: string,
    esperado: number,
    totalRPC: number,
    bearer = true
  ) {
    escenario = opciones;
    llamadasRPC = [];

    const respuesta = await manejar(
      new Request("http://127.0.0.1/prueba", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(bearer ? { Authorization: "Bearer ficticio" } : {})
        },
        body: JSON.stringify({ evento_id: evento, token })
      })
    );

    const cuerpo = await respuesta.json();

    assert.equal(
      respuesta.status,
      esperado,
      `${nombre}: respuesta ${JSON.stringify(cuerpo)}`
    );

    assert.equal(llamadasRPC.length, totalRPC, nombre);

    if (totalRPC > 0) {
      assert.equal(
        llamadasRPC[0].nombre,
        "consultar_qr_acceso_evento"
      );
      assert.equal(
        (llamadasRPC[0].parametros as Record<string, unknown>).p_evento_id,
        CHIAPAS
      );
    }

    console.log("APROBADO:", nombre);
  }

  const token = "a".repeat(64);

  await probar("Sin autorizacion", {}, CHIAPAS, token, 401, 0, false);
  await probar("Sesion invalida", { sesion: false }, CHIAPAS, token, 401, 0);
  await probar("Usuario desactivado", { activo: false }, CHIAPAS, token, 403, 0);
  await probar("Rol no autorizado", { rol: "validador" }, CHIAPAS, token, 403, 0);
  await probar("Evento RADEVS rechazado", { permiso: true }, RADEVS, token, 400, 0);
  await probar("Sin permiso Chiapas", {}, CHIAPAS, token, 403, 0);
  await probar("Token invalido", { permiso: true }, CHIAPAS, "INVALIDO", 200, 0);
  await probar("RPC exclusiva Chiapas", { permiso: true }, CHIAPAS, token, 200, 1);

  console.log("8 PRUEBAS NATIVAS DENO APROBADAS");
  console.log("SIN CONEXION REAL A SUPABASE");
}
finally {
  await Deno.remove(temporal);
}
