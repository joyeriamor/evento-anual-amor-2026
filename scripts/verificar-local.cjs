const {spawnSync}=require('node:child_process');
const commands=[
 ['node_modules/eslint/bin/eslint.js','.'],
 ['node_modules/typescript/bin/tsc','-b'],
 ['node_modules/vite/bin/vite.js','build'],
 ['scripts/check-edge.cjs'],['scripts/test-seguridad.cjs'],['scripts/test-edge-acceso-chiapas.cjs'],
 ['tests/chiapas/sql-eventos.integration.mjs'],['tests/chiapas/catalogo.integration.mjs'],['tests/chiapas/rollback-pg-temp.integration.mjs'],['scripts/test-e2e-local.cjs'],
];
for(const args of commands){
 console.log(`VERIFICANDO: ${args[0]}`);
 const result=spawnSync(process.execPath,args,{stdio:'inherit',env:process.env});
 if(result.error)throw result.error;
 if(result.status!==0)process.exit(result.status??1);
}
console.log('Verificación local completa aprobada. Ninguna acción de despliegue.');
