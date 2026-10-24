const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const assert = require("node:assert/strict");

const ts = require(path.resolve(
  "node_modules/typescript/lib/typescript.js"
));

const CHIAPAS = "3dc92160-79af-4bf7-b770-263038e88900";
const RADEVS = "43e67bda-d19d-4c0e-a639-e85f2d62f294";
const USUARIO = "aa111111-1111-4111-8111-111111111111";
const PAGO = "cc111111-1111-4111-8111-111111111111";
const REGISTRO = "bb111111-1111-4111-8111-111111111111";

const archivos = [
  {
    tipo: "pago",
    ruta: "supabase/functions/validar-pago-chiapas/index.ts",
    cuerpo: {
      pago_id: PAGO,
      accion: "aprobar",
      evento_id: RADEVS
    }
  },
  {
    tipo: "invitacion",
    ruta: "supabase/functions/administrar-invitacion-chiapas/index.ts",
    cuerpo: {
      registro_id: REGISTRO,
      accion: "cortesia",
      evento_id: RADEVS
    }
  }
];

function preparar(ruta, estado = {}) {
  const fuente = fs.readFileSync(ruta, "utf8");

  const resultado = ts.transpileModule(fuente, {
    fileName: ruta,
    reportDiagnostics: true,
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.CommonJS
    }
  });

  const errores = (resultado.diagnostics || [])
    .filter(x => x.category === ts.DiagnosticCategory.Error);

  assert.equal(errores.length, 0, "Sintaxis TypeScript invalida");

  const estadisticas = {
    rpc: [],
    asignaciones: 0
  };

  function consulta(tabla) {
    const filtros = {};
    const objeto = {
      select() {
        return this;
      },
      eq(campo, valor) {
        filtros[campo] = valor;
        return this;
      },
      async single() {
        assert.equal(tabla, "usuarios");
        assert.equal(filtros.id, USUARIO);

        return {
          data: {
            rol: estado.rol || "administrador",
            activo: estado.inactivo ? false : true
          },
          error: null
        };
      },
      async maybeSingle() {
        assert.equal(tabla, "usuarios_eventos");

        estadisticas.asignaciones++;

        assert.equal(filtros.usuario_id, USUARIO);
        assert.equal(filtros.evento_id, CHIAPAS);
        assert.equal(filtros.activo, true);

        if (estado.errorAsignacion) {
          return {
            data: null,
            error: new Error("Error ficticio de asignacion")
          };
        }

        return {
          data: estado.sinAsignacion
            ? null
            : { usuario_id: USUARIO },
          error: null
        };
      }
    };

    return objeto;
  }

  const cliente = {
    auth: {
      async getUser(token) {
        if (token === "invalido") {
          return {
            data: { user: null },
            error: new Error("Token ficticio invalido")
          };
        }

        return {
          data: { user: { id: USUARIO } },
          error: null
        };
      }
    },
    from: consulta,
    async rpc(nombre, argumentos) {
      estadisticas.rpc.push({
        nombre,
        argumentos
      });

      return {
        data: { ok: true },
        error: null
      };
    }
  };

  let manejador = null;

  const requireSimulado = nombre => {
    if (nombre.includes("http/server.ts")) {
      return {
        serve: fn => {
          manejador = fn;
        }
      };
    }

    if (nombre.includes("supabase-js")) {
      return {
        createClient: () => cliente
      };
    }

    throw new Error("Importacion inesperada: " + nombre);
  };

  vm.runInNewContext(resultado.outputText, {
    exports: {},
    require: requireSimulado,
    Deno: {
      env: {
        get: () => "configuracion-ficticia"
      }
    },
    Request,
    Response,
    Headers,
    TextDecoder,
    TextEncoder,
    console
  }, {
    filename: ruta,
    timeout: 3000
  });

  assert.equal(typeof manejador, "function");

  return {
    manejador,
    estadisticas
  };
}

let aprobadas = 0;

async function probar(config, nombre, estado, token, esperado, rpc = null) {
  const entorno = preparar(config.ruta, estado);

  const headers = {
    "Content-Type": "application/json"
  };

  if (token !== null) {
    headers.Authorization = "Bearer " + token;
  }

  const req = new Request("https://prueba.local/edge", {
    method: "POST",
    headers,
    body: JSON.stringify(config.cuerpo)
  });

  const respuesta = await entorno.manejador(req);
  const json = await respuesta.json();

  assert.equal(
    respuesta.status,
    esperado,
    `${config.tipo} / ${nombre}: respuesta ${JSON.stringify(json)}`
  );

  if (rpc === null) {
    assert.equal(
      entorno.estadisticas.rpc.length,
      0,
      `${config.tipo} / ${nombre}: ejecuto una RPC no autorizada`
    );
  } else {
    assert.equal(entorno.estadisticas.rpc.length, 1);
    assert.equal(entorno.estadisticas.rpc[0].nombre, rpc.nombre);
    assert.equal(
      entorno.estadisticas.rpc[0].argumentos.p_admin_id,
      USUARIO
    );

    if (rpc.reemitir !== undefined) {
      assert.equal(
        entorno.estadisticas.rpc[0].argumentos.p_reemitir,
        rpc.reemitir
      );
    }

    assert.equal(json.ok, true);
    assert.equal(entorno.estadisticas.asignaciones, 1);
  }

  aprobadas++;
  console.log("APROBADO:", config.tipo, "-", nombre);
}

(async () => {
  for (const config of archivos) {
    await probar(config, "sin sesion", {}, null, 401);

    await probar(
      config, "token invalido", {}, "invalido", 401
    );

    await probar(
      config, "rol incorrecto", { rol: "validador" }, "valido", 403
    );

    await probar(
      config, "cuenta inactiva", { inactivo: true }, "valido", 403
    );

    await probar(
      config, "sin asignacion", { sinAsignacion: true }, "valido", 403
    );

    await probar(
      config, "error en asignacion",
      { errorAsignacion: true }, "valido", 500
    );
  }

  const pagos = archivos[0];
  const invitaciones = archivos[1];

  await probar(
    pagos,
    "aprobar pago Chiapas",
    {},
    "valido",
    200,
    { nombre: "validar_pago_admin_chiapas" }
  );

  await probar(
    {
      ...pagos,
      cuerpo: {
        pago_id: PAGO,
        accion: "rechazar",
        motivo: "Comprobante ficticio invalido",
        evento_id: RADEVS
      }
    },
    "rechazar pago Chiapas",
    {},
    "valido",
    200,
    { nombre: "validar_pago_admin_chiapas" }
  );

  await probar(
    invitaciones,
    "autorizar cortesia",
    {},
    "valido",
    200,
    { nombre: "autorizar_cortesia_admin_chiapas" }
  );

  await probar(
    {
      ...invitaciones,
      cuerpo: {
        registro_id: REGISTRO,
        accion: "recuperar",
        evento_id: RADEVS
      }
    },
    "recuperar QR",
    {},
    "valido",
    200,
    {
      nombre: "recuperar_invitacion_admin_chiapas",
      reemitir: false
    }
  );

  await probar(
    {
      ...invitaciones,
      cuerpo: {
        registro_id: REGISTRO,
        accion: "reemitir",
        evento_id: RADEVS
      }
    },
    "reemitir QR",
    {},
    "valido",
    200,
    {
      nombre: "recuperar_invitacion_admin_chiapas",
      reemitir: true
    }
  );

  assert.equal(aprobadas, 17);

  console.log("");
  console.log("RESULTADO: APROBADO");
  console.log("PRUEBAS SUPERADAS:", aprobadas, "DE 17");
  console.log("SUPABASE: SIN SOLICITUDES REALES");
})().catch(error => {
  console.error("PRUEBA FALLIDA:", error);
  process.exitCode = 1;
});