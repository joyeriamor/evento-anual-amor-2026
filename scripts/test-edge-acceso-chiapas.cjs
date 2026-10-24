const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const ts = require("typescript");

const CHIAPAS = "3dc92160-79af-4bf7-b770-263038e88900";
const RADEVS = "43e67bda-d19d-4c0e-a639-e85f2d62f294";
const ruta = "supabase/functions/consultar-acceso-evento/index.ts";

// Legacy QR-handler unit test; shared guard is exercised by aislamiento-eventos.test.cjs.
const fuente = fs.readFileSync(ruta, "utf8")
  .replace(/^import .*_shared\/evento[^\n]*\n/m, '')
  .replace(/serveEvento\(\{[^\n]+?\}, /, 'Deno.serve(');
const importacion = /^import \{ createClient \} from ['"][^'"]+['"];?/m;

assert.match(fuente, importacion);

const js = ts.transpileModule(
  fuente.replace(importacion, "const createClient = __mockCreateClient;"),
  { compilerOptions: {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.None
  }}
).outputText;

function crearEntorno(config = {}) {
  const {
    sesion = true,
    rol = "acceso",
    activo = true,
    permiso = false
  } = config;

  let controlador;
  const llamadasRPC = [];
  let lecturasPrivadas = 0;

  const clienteUsuario = {
    auth: {
      getUser: async () => ({
        data: { user: sesion ? { id: "usuario-prueba" } : null },
        error: sesion ? null : { message: "Sesion invalida" }
      })
    },
    rpc: async (nombre, parametros) => {
      llamadasRPC.push({ nombre, parametros });
      return {
        data: { ok: false, estado: "qr_invalido" },
        error: null
      };
    }
  };

  const clienteAdmin = {
    from: (tabla) => {
      if (tabla === "usuarios") {
        return {
          select: () => ({
            eq: () => ({
              single: async () => ({
                data: { rol, activo }
              })
            })
          })
        };
      }

      if (tabla === "usuarios_eventos") {
        return {
          select: () => ({
            eq() { return this; },
            maybeSingle: async () => ({
              data: permiso ? { usuario_id: "usuario-prueba" } : null,
              error: null
            })
          })
        };
      }

      lecturasPrivadas++;
      throw new Error("Consulta inesperada: " + tabla);
    }
  };

  const entorno = {
    Request,
    Response,
    console,
    __mockCreateClient: (_url, clave) =>
      clave === "servicio-ficticio"
        ? clienteAdmin
        : clienteUsuario,
    Deno: {
      env: {
        get: (nombre) => ({
          SUPABASE_URL: "https://example.invalid",
          SUPABASE_ANON_KEY: "anon-ficticio",
          SUPABASE_SERVICE_ROLE_KEY: "servicio-ficticio"
        })[nombre]
      },
      serve: (fn) => { controlador = fn; }
    }
  };

  vm.runInNewContext(js, entorno, { timeout: 2000 });

  return {
    llamadasRPC,
    get lecturasPrivadas() { return lecturasPrivadas; },
    solicitar: async (evento, token, autorizacion = true) => {
      const respuesta = await controlador(new Request(
        "https://example.invalid/test",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(autorizacion ? { Authorization: "Bearer ficticio" } : {})
          },
          body: JSON.stringify({ evento_id: evento, token })
        }
      ));

      return {
        status: respuesta.status,
        datos: await respuesta.json()
      };
    }
  };
}

async function probar(nombre, config, evento, token, codigo, rpc, autorizado = true) {
  const entorno = crearEntorno(config);
  const resultado = await entorno.solicitar(evento, token, autorizado);

  assert.equal(resultado.status, codigo, nombre);
  assert.equal(entorno.llamadasRPC.length, rpc, nombre);
  assert.equal(entorno.lecturasPrivadas, 0, nombre);

  if (rpc > 0) {
    assert.equal(
      entorno.llamadasRPC[0].nombre,
      "consultar_qr_acceso_evento"
    );
    assert.equal(
      entorno.llamadasRPC[0].parametros.p_evento_id,
      CHIAPAS
    );
  }

  console.log("APROBADO:", nombre);
}

(async () => {
  const token = "a".repeat(64);

  await probar("Sin autorizacion", {}, CHIAPAS, token, 401, 0, false);
  await probar("Sesion invalida", { sesion:false }, CHIAPAS, token, 401, 0);
  await probar("Usuario desactivado", { activo:false }, CHIAPAS, token, 403, 0);
  await probar("Rol no permitido", { rol:"validador" }, CHIAPAS, token, 403, 0);
  await probar("Intento de usar RADEVS", { permiso:true }, RADEVS, token, 400, 0);
  await probar("Operador sin asignacion Chiapas", {}, CHIAPAS, token, 403, 0);
  await probar("Token malformado", { permiso:true }, CHIAPAS, "INVALIDO", 200, 0);
  await probar("RPC correcta para Chiapas", { permiso:true }, CHIAPAS, token, 200, 1);

  console.log("8 PRUEBAS APROBADAS - SIN CONEXION A SUPABASE");
})().catch(error => {
  console.error("PRUEBA FALLIDA:", error);
  process.exitCode = 1;
});