const fs=require('node:fs');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const files=fs.readdirSync('supabase/functions').flatMap(name=>{
 const file=path.join('supabase/functions',name,'index.ts');return fs.existsSync(file)?[file]:[];
});
const args=['check','--lock=supabase/edge-check.lock','--frozen=true','--node-modules-dir=none',...files];
const result=process.env.DENO_BIN
 ?spawnSync(process.env.DENO_BIN,args,{stdio:'inherit'})
 :spawnSync(process.execPath,[require.resolve('deno/bin.cjs'),...args],{stdio:'inherit'});
if(result.error)throw result.error;
process.exit(result.status??1);
