const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const ts = require(path.resolve("node_modules/typescript/lib/typescript.js"));

const ARCHIVO = "supabase/functions/bandeja-personal-chiapas/index.ts";
const CHIAPAS = "3dc92160-79af-4bf7-b770-263038e88900";
const RADEVS = "43e67bda-d19d-4c0e-a639-e85f2d62f294";
const USER = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1";

const registros = [
  {
    id: "chi-1", evento_id: CHIAPAS, folio: "CHI-1",
    estado: "pendiente", promotora_id: "prom-chi",
    created_at: "2026-10-24T10:00:00Z", exento_pago: false
  },
  {
    id: "chi-2", evento_id: CHIAPAS, folio: "CHI-2",
    estado: "pendiente", promotora_id: "prom-chi",
    created_at: "2026-10-24T11:00:00Z", exento_pago: false
  },
  {
    id: "rad-1", evento_id: RADEVS, folio: "RAD-1",
    estado: "pendiente", promotora_id: "prom-rad",
    created_at: "2026-10-24T12:00:00Z", exento_pago: false
  }
];

const pagos = [
  {
    id: "p-chi-1", registro_id: "chi-1",
    estado: "pendiente", importe: 300, referencia: "CHI1",
    comprobante_path: "chiapas/uno.jpg",
    created_at: "2026-10-24T10:00:00Z"
  },
  {
    id: "p-chi-2", registro_id: "chi-2",
    estado: "revision", importe: 300, referencia: "CHI2",
    comprobante_path: "chiapas/dos.jpg",
    created_at: "2026-10-24T11:00:00Z"
  },
  {
    id: "p-rad-1", registro_id: "rad-1",
    estado: "pendiente", importe: 300, referencia: "RAD1",
    comprobante_path: "radevs/privado.jpg",
    created_at: "2026-10-24T12:00:00Z"
  }
];

const promotoras = [
  {
    id: "prom-chi", nombres: "CHIAPAS",
    apellidos: "FICTICIA", telefono_whatsapp: "0001"
  },
  {
    id: "prom-rad", nombres: "RADEVS",
    apellidos: "FICTICIA", telefono_whatsapp: "0002"
  }
];

const fuente = fs.readFileSync(ARCHIVO, "utf8");

const compilacion = ts.transpileModule(fuente, {
  fileName: ARCHIVO,
  reportDiagnostics: true,
  compilerOptions: {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.CommonJS
  }
});

assert.equal(
  (compilacion.diagnostics || [])
    .filter(x => x.category === ts.DiagnosticCategory.Error).length,
  0,
  "Error de sintaxis TypeScript"
);

function entorno(caso) {
  const estado = caso.estado || {};
  const actividad = {
    consultas: [],
    comprobantesFirmados: []
  };

  function consultar(tabla) {
    const filtros = {};
    const conjuntos = {};
    const pasos = [];
    let seleccion = "";
    let limite = null;

    const q = {
      select(campos) {
        seleccion = campos;
        return this;
      },
      eq(campo, valor) {
        filtros[campo] = valor;
        pasos.push("eq:" + campo);
        return this;
      },
      in(campo, valores) {
        conjuntos[campo] = valores;
        pasos.push("in:" + campo);
        return this;
      },
      order() {
        pasos.push("order");
        return this;
      },
      limit(numero) {
        limite = numero;
        pasos.push("limit");
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
              activo: estado.inactivo ? false : true
            },
            error: null
          };
        }

        assert.equal(tabla, "usuarios_eventos");
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
            ? null : { usuario_id: USER },
          error: null
        };
      },
      then(resolve, reject) {
        return Promise.resolve().then(() => {
          actividad.consultas.push(tabla);

          if (tabla === "pagos") {
            assert.ok(
              seleccion.includes("registros!inner(evento_id)"),
              "Los pagos requieren INNER JOIN con registros"
            );
            assert.equal(filtros["registros.evento_id"], CHIAPAS);
            assert.ok(
              pasos.indexOf("eq:registros.evento_id") <
              pasos.indexOf("limit"),
              "El evento debe filtrarse antes del limite"
            );
            assert.equal(limite, 500);

            if (estado.errorPagos) {
              return {
                data: null,
                error: { message: "Fallo ficticio de pagos" }
              };
            }

            return {
              data: pagos.filter(p => {
                const r = registros.find(r => r.id === p.registro_id);
                return r?.evento_id === filtros["registros.evento_id"]
                  && conjuntos.estado.includes(p.estado);
              }),
              error: null
            };
          }

          if (tabla === "registros") {
            assert.equal(filtros.evento_id, CHIAPAS);

            if (limite !== null) {
              assert.equal(limite, 500);
              assert.ok(
                pasos.indexOf("eq:evento_id") <
                pasos.indexOf("limit"),
                "Filtrar participantes antes del limite"
              );
            } else {
              assert.ok(
                conjuntos.id,
                "La consulta por pagos debe restringir IDs"
              );
            }

            return {
              data: registros.filter(r =>
                r.evento_id === filtros.evento_id &&
                (!conjuntos.id || conjuntos.id.includes(r.id))
              ),
              error: null
            };
          }

          if (tabla === "promotoras") {
            assert.ok(conjuntos.id);
            return {
              data: promotoras.filter(p => conjuntos.id.includes(p.id)),
              error: null
            };
          }

          throw new Error("Consulta inesperada: " + tabla);
        }).then(resolve, reject);
      }
    };

    return q;
  }

  const db = {
    from: consultar,
    storage: {
      from(bucket) {
        assert.equal(bucket, "comprobantes-pago");

        return {
          async createSignedUrl(ruta, segundos) {
            assert.equal(segundos, 60);
            actividad.comprobantesFirmados.push(ruta);

            return {
              data: {
                signedUrl: "https://firmas-ficticias.test/" +
                  encodeURIComponent(ruta)
              },
              error: null
            };
          }
        };
      }
    }
  };

  const claves = {
    SUPABASE_URL: "https://supabase-ficticio.test",
    SUPABASE_ANON_KEY: "anon-ficticia",
    SUPABASE_SERVICE_ROLE_KEY: "service-ficticia"
  };

  function createClient(url, clave) {
    assert.equal(url, claves.SUPABASE_URL);

    if (clave === claves.SUPABASE_SERVICE_ROLE_KEY) {
      return db;
    }

    assert.equal(clave, claves.SUPABASE_ANON_KEY);

    return {
      auth: {
        async getUser(token) {
          if (token === "invalido") {
            return {
              data: { user: null },
              error: { message: "Token invalido" }
            };
          }

          return {
            data: { user: { id: USER } },
            error: null
          };
        }
      }
    };
  }

  let manejar = null;

  vm.runInNewContext(compilacion.outputText, {
    exports: {},
    require(nombre) {
      if (nombre.includes("supabase-js")) {
        return { createClient };
      }
      throw new Error("Dependencia no simulada: " + nombre);
    },
    Deno: {
      env: { get: nombre => claves[nombre] },
      serve: fn => { manejar = fn; }
    },
    Request, Response, Headers, URL,
    TextEncoder, TextDecoder, console
  }, {
    filename: ARCHIVO,
    timeout: 3000
  });

  assert.equal(typeof manejar, "function");

  return { manejar, actividad };
}

const casos = [
  { nombre: "Sin sesion", token: null, status: 401 },
  { nombre: "Token invalido", token: "invalido", status: 401 },
  { nombre: "Administrador inactivo", estado: { inactivo: true }, status: 403 },
  { nombre: "Rol incorrecto", estado: { rol: "acceso" }, status: 403 },
  { nombre: "Error de perfil", estado: { errorPerfil: true }, status: 500 },
  { nombre: "Sin asignacion", estado: { sinAsignacion: true }, status: 403 },
  { nombre: "Error de asignacion", estado: { errorAsignacion: true }, status: 500 },
  { nombre: "Tipo invalido", cuerpo: { tipo: "otro" }, status: 400 },
  { nombre: "JSON malformado", texto: "{invalido", status: 400 },
  { nombre: "JSON arreglo", texto: "[]", status: 400 },
  { nombre: "Pagos de RADEVS solicitados", cuerpo: { tipo: "pagos", evento_id: RADEVS }, status: 403 },
  { nombre: "Participantes de RADEVS solicitados", cuerpo: { tipo: "participantes", evento_id: RADEVS }, status: 403 },
  { nombre: "Validador consulta pagos", estado: { rol: "validador" }, status: 200, tipo: "pagos" },
  { nombre: "Recepcion consulta participantes", estado: { rol: "recepcion" }, cuerpo: { tipo: "participantes" }, status: 200, tipo: "participantes" },
  { nombre: "Validador no puede consultar participantes", estado: { rol: "validador" }, cuerpo: { tipo: "participantes" }, status: 403 },
  { nombre: "Recepcion no puede consultar pagos", estado: { rol: "recepcion" }, status: 403 },
  { nombre: "Administrador consulta pagos Chiapas", status: 200, tipo: "pagos" },
  { nombre: "Administrador consulta participantes Chiapas", cuerpo: { tipo: "participantes", evento_id: CHIAPAS }, status: 200, tipo: "participantes" },
  { nombre: "Fallo al consultar pagos", estado: { errorPagos: true }, status: 500 }
];

(async () => {
  let aprobadas = 0;

  for (const caso of casos) {
    const { manejar, actividad } = entorno(caso);
    const headers = { "Content-Type": "application/json" };

    if (caso.token !== null) {
      headers.Authorization = "Bearer " + (caso.token || "valido");
    }

    const cuerpo = caso.texto !== undefined
      ? caso.texto
      : JSON.stringify(caso.cuerpo || { tipo: "pagos" });

    const req = new Request("https://prueba-local.test/bandeja-personal-chiapas", {
      method: "POST", headers, body: cuerpo
    });

    const respuesta = await manejar(req);
    const json = await respuesta.json();

    assert.equal(
      respuesta.status, caso.status,
      caso.nombre + ": " + JSON.stringify(json)
    );

    if (caso.status === 200) {
      assert.equal(json.ok, true);
      assert.equal(json.total, 2);
      assert.equal(json.limite, 20);
      assert.equal(json.registros.length, 2);

      for (const fila of json.registros) {
        assert.ok(fila.folio.startsWith("CHI-"));
        assert.ok(!JSON.stringify(fila).includes("RADEVS"));
        assert.ok(!JSON.stringify(fila).includes("radevs/"));
        assert.equal(fila.comprobante_path, undefined);
      }

      if (caso.tipo === "pagos") {
        assert.deepEqual(
          actividad.comprobantesFirmados.slice().sort(),
          ["chiapas/dos.jpg", "chiapas/uno.jpg"].sort()
        );

        for (const fila of json.registros) {
          assert.ok(fila.comprobante_url?.includes("chiapas%2F"));
        }
      } else {
        assert.equal(actividad.comprobantesFirmados.length, 0);
        assert.ok(
          json.registros.every(r => r.comprobante_url === null)
        );
      }
    } else {
      assert.equal(json.ok, false);
      assert.equal(actividad.comprobantesFirmados.length, 0);

      if (!caso.estado?.errorPagos) {
        assert.ok(
          !actividad.consultas.includes("pagos") &&
          !actividad.consultas.includes("registros"),
          caso.nombre + ": consulto datos privados sin permiso"
        );
      }
    }

    console.log("APROBADO:", caso.nombre);
    aprobadas++;
  }

  assert.equal(aprobadas, 19);

  console.log("");
  console.log("RESULTADO: APROBADO");
  console.log("PRUEBAS SUPERADAS: 19 DE 19");
  console.log("COMPROBANTES RADEVS FIRMADOS: 0");
  console.log("SUPABASE: SIN SOLICITUDES REALES");
})().catch(error => {
  console.error("PRUEBA FALLIDA:", error);
  process.exitCode = 1;
});