'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const leer = p => fs.readFileSync(path.join(root, p), 'utf8');

test('selector restringe Chiapas a LUIS y VIRIDIANA', () => {
  const s = leer('src/pages/SelectorAsesor.tsx');
  assert.match(s, /if \(soloChiapas\)/);
  assert.match(s, /nombre === "LUIS" \|\| nombre === "VIRIDIANA"/);
  assert.match(leer('src/pages/Registro.tsx'), /soloChiapas=\{evento === "chiapas"\}/);
});

test('registro público Chiapas rechaza otros asesores ANTES de almacenar fotos', () => {
  for (const f of ['registrar-participante-chiapas', 'registrar-prueba-admin-chiapas']) {
    const s = leer('supabase/functions/' + f + '/index.ts');
    const validador = s.indexOf('nombreAsesor !== "LUIS" && nombreAsesor !== "VIRIDIANA"');
    const subida = s.indexOf('const subidaFoto =');
    assert.ok(validador >= 0, f + ': restricción ausente');
    assert.ok(subida > validador, f + ': restricción debe preceder la subida');
  }
});

test('filtro backend aplica antes de paginación y excluye pruebas', () => {
  const s = leer('supabase/functions/listar-participantes/index.ts');
  assert.match(s, /const asesorId = parametros.asesor_id/);
  assert.match(s, /consulta = consulta.eq\("asesor_id", asesorId\).eq\("es_prueba", false\)/);
  assert.ok(s.indexOf('consulta.eq("asesor_id"') < s.indexOf('consulta.range(inicio, fin)'));
  assert.match(s, /serveEvento\(\{ roles: \['administrador'\] \}/);
});

test('S’S y muestra el total del servidor', () => {
  const s = leer('src/pages/ParticipantesAdmin.tsx');
  assert.doesNotMatch(s, /!esChiapas && \(/);
  assert.doesNotMatch(s, /if \(esChiapas\) return;/);
  assert.match(s, /\["LUIS", "VIRIDIANA"\]\.includes/);
  assert.match(s, /Filtrar por asesor/);
  assert.match(s, /asesor_id: asesorId/);
  assert.match(s, /setTotal\(/);
  assert.match(s, /respuesta.total/);
});
