const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const ts = require(path.resolve("node_modules/typescript/lib/typescript.js"));

const ARCHIVO = "supabase/functions/bandejas-admin-chiapas/index.ts";
const CHIAPAS = "3dc92160-79af-4bf7-b770-263038e88900";
const RADEVS = "43e67bda-d19d-4c0e-a639-e85f2d62f294";
const USER = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1";
const RPC = "bandejas_admin_chiapas_paginadas";

const fuente = fs.readFileSync(ARCHIVO, "utf8");
const compilacion = ts.transpileModule(fuente, {
  fileName: ARCHIVO,
  reportDiagnostics: true,
  compilerOptions: {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.CommonJS
  }
});

const errores = (compilacion.diagnostics || [])
  .filter(x => x.category === ts.DiagnosticCategory.Error);

assert.equal(errores.length, 0, "Error de sintaxis TypeScript");

function preparar(caso) {
  const estado = caso.estado || {};
  const estadisticas = {
    auth: 0,
    asignaciones: 0,
    rpc: []
  };

  function consulta(tabla) {
    const filtros = {};

    return {
      select() { return this; },
      eq(campo, valor) {
        filtros[campo] = valor;
        return this;
      },
      async maybeSingle() {
        if (tabla === "usuarios") {
          assert.equal(filtros.id, USER);

          if (estado.errorPerfil) {
            return {
              data: null,
              error: { message: "Error ficticio de perfil" }
            };
          }

          return {
            data: {
              rol: estado.rol || "administrador",
              activo: estado.activo === false ? false : true
            },
            error: null
          };
        }

        if (tabla === "usuarios_eventos") {
          estadisticas.asignaciones++;

          assert.equal(filtros.usuario_id, USER);
          assert.equal(filtros.evento_id, CHIAPAS);
          assert.equal(filtros.activo, true);

          if (estado.errorAsignacion) {
            return {
              data: null,
              error: { message: "Error ficticio de asignacion" }
            };
          }

          return {
            data: estado.sinAsignacion
              ? null
              : { usuario_id: USER },
            error: null
          };
        }

        throw new Error("Tabla inesperada: " + tabla);
      }
    };
  }

  const db = {
    from: consulta,
    async rpc(nombre, argumentos) {
      estadisticas.rpc.push({ nombre, argumentos });

      if (estado.errorRPC) {
        return {
          data: null,
          error: { message: "Error ficticio de RPC" }
        };
      }

      return {
        data: {
          total: 25,
          registros: [{ folio: "CHI-21" }]
        },
        error: null
      };
    }
  };

  const configuracion = {
    SUPABASE_URL: "https://supabase-ficticio.test",
    SUPABASE_ANON_KEY: "anon-ficticia",
    SUPABASE_SERVICE_ROLE_KEY: "service-ficticia"
  };

  const createClient = (url, key) => {
    assert.equal(url, configuracion.SUPABASE_URL);

    if (key === configuracion.SUPABASE_SERVICE_ROLE_KEY) {
      return db;
    }

    assert.equal(key, configuracion.SUPABASE_ANON_KEY);

    return {
      auth: {
        async getUser() {
          estadisticas.auth++;

          if (caso.token === "invalido") {
            return {
              data: { user: null },
              error: { message: "JWT ficticio invalido" }
            };
          }

          return {
            data: { user: { id: USER } },
            error: null
          };
        }
      }
    };
  };

  let manejar = null;

  const requireSimulado = nombre => {
    // Legacy handler unit tests; the real shared guard is tested by aislamiento-eventos.test.cjs.
    if (nombre.includes('_shared/evento')) return { CHIAPAS: '3dc92160-79af-4bf7-b770-263038e88900', RADEVS: '43e67bda-d19d-4c0e-a639-e85f2d62f294', serveEvento: (_opciones, fn) => { manejar = fn; } };
    if (nombre.includes("supabase-js")) {
      return { createClient };
    }

    throw new Error("Dependencia inesperada: " + nombre);
  };

  vm.runInNewContext(compilacion.outputText, {
    exports: {},
    require: requireSimulado,
    Deno: {
      env: { get: nombre => configuracion[nombre] },
      serve: fn => { manejar = fn; }
    },
    Request,
    Response,
    Headers,
    URL,
    TextEncoder,
    TextDecoder,
    console
  }, {
    filename: ARCHIVO,
    timeout: 3000
  });

  assert.equal(typeof manejar, "function");

  return { manejar, estadisticas };
}

const casos = [
  { nombre: "Sin sesion", token: null, status: 401 },
  { nombre: "Token invalido", token: "invalido", status: 401 },
  { nombre: "Rol validador", estado: { rol: "validador" }, status: 403 },
  { nombre: "Cuenta inactiva", estado: { activo: false }, status: 403 },
  { nombre: "Error de perfil", estado: { errorPerfil: true }, status: 500 },
  { nombre: "Sin asignacion Chiapas", estado: { sinAsignacion: true }, status: 403 },
  { nombre: "Error de asignacion", estado: { errorAsignacion: true }, status: 500 },
  {
    nombre: "Intento de consultar RADEVS",
    cuerpo: { tipo: "pagos", evento_id: RADEVS },
    status: 403
  },
  {
    nombre: "Tipo de bandeja invalido",
    cuerpo: { tipo: "otro" },
    status: 400
  },
  {
    nombre: "JSON malformado",
    texto: "{JSON incorrecto",
    status: 400
  },
  {
    nombre: "Pagos Chiapas autorizados",
    cuerpo: { tipo: "pagos", pagina: 2, busqueda: "CHI" },
    status: 200,
    tipo: "pagos"
  },
  {
    nombre: "Invitaciones Chiapas autorizadas",
    cuerpo: { tipo: "invitaciones" },
    status: 200,
    tipo: "invitaciones"
  },
  {
    nombre: "Evento Chiapas explicito",
    cuerpo: { tipo: "pagos", evento_id: CHIAPAS },
    status: 200,
    tipo: "pagos"
  },
  {
    nombre: "Error de RPC",
    estado: { errorRPC: true },
    status: 500,
    debeLlamarRPC: true
  }
];

(async () => {
  let aprobadas = 0;

  for (const caso of casos) {
    const { manejar, estadisticas } = preparar(caso);

    const headers = { "Content-Type": "application/json" };

    if (caso.token !== null) {
      headers.Authorization = "Bearer " + (caso.token || "valido");
    }

    const cuerpo = caso.texto !== undefined
      ? caso.texto
      : JSON.stringify(caso.cuerpo || { tipo: "pagos" });

    const req = new Request(
      "https://servidor-ficticio.test/bandejas-admin-chiapas",
      { method: "POST", headers, body: cuerpo }
    );

    const respuesta = await manejar(req);
    const json = await respuesta.json();

    assert.equal(
      respuesta.status,
      caso.status,
      caso.nombre + ": " + JSON.stringify(json)
    );

    const esperaRPC = caso.status === 200 || caso.debeLlamarRPC;

    if (!esperaRPC) {
      assert.equal(
        estadisticas.rpc.length,
        0,
        caso.nombre + ": ejecuto una RPC no autorizada"
      );
    } else {
      assert.equal(estadisticas.rpc.length, 1);

      const llamada = estadisticas.rpc[0];

      assert.equal(llamada.nombre, RPC);
      assert.equal(llamada.argumentos.p_admin_id, USER);
      assert.equal(llamada.argumentos.p_tipo, (caso.cuerpo || {}).tipo || "pagos");
      assert.equal(llamada.argumentos.p_pagina, (caso.cuerpo || {}).pagina || 1);
      assert.equal(llamada.argumentos.p_busqueda, (caso.cuerpo || {}).busqueda || "");
      assert.equal(estadisticas.asignaciones, 1);
    }

    if (caso.status === 200) {
      assert.equal(json.ok, true);
      assert.equal(json.tipo, caso.tipo);
      assert.equal(json.total, 25);
      assert.equal(json.limite, 20);
      assert.equal(json.pagina, (caso.cuerpo || {}).pagina || 1);
      assert.equal(json.limitado, false);
      assert.equal(json.registros.length, 1);
      assert.equal(json.registros[0].folio, "CHI-21");
    } else {
      assert.equal(json.ok, false);
    }

    console.log("APROBADO:", caso.nombre);
    aprobadas++;
  }

  assert.equal(aprobadas, 14);

  console.log("");
  console.log("RESULTADO: APROBADO");
  console.log("PRUEBAS SUPERADAS: 14 DE 14");
  console.log("SUPABASE: SIN SOLICITUDES REALES");
})().catch(error => {
  console.error("PRUEBA FALLIDA:", error);
  process.exitCode = 1;
});
