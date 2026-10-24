const { spawnSync } = require('node:child_process');
for (const test of ['edge-admin-http','bandejas-admin-chiapas-http','bandeja-personal-chiapas-http','aislamiento-eventos']) {
  const result = spawnSync(process.execPath, [`tests/chiapas/${test}.test.cjs`], { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}
