// Isolated localhost server with fictitious credentials; no deployment.
const {spawn}=require('node:child_process');
const net=require('node:net');
const port=5178;
let server,runner;
const waitFor=async()=>{
 for(let i=0;i<100;i++){
  if(server.exitCode!==null)throw Error('El servidor local terminó antes de las pruebas');
  try{const r=await fetch(`http://127.0.0.1:${port}/evento-anual-amor-2026/`);if(r.ok)return;}catch{}
  await new Promise(r=>setTimeout(r,100));
 }
 throw Error('El frontend local no respondió');
};
(async()=>{
 // Fail before starting if the port belongs to another process.
 const probe=net.createServer();await new Promise((resolve,reject)=>probe.once('error',reject).listen(port,'127.0.0.1',resolve));await new Promise(r=>probe.close(r));
 server=spawn(process.execPath,[require('node:path').resolve('node_modules/vite/bin/vite.js'),'--host','127.0.0.1','--port',String(port),'--strictPort'],{
  env:{...process.env,VITE_SUPABASE_URL:'http://127.0.0.1:54321',VITE_SUPABASE_PUBLISHABLE_KEY:'local-test-only'},stdio:['ignore','pipe','pipe'],
 });
 const output=[];server.stdout.on('data',b=>output.push(b.toString()));server.stderr.on('data',b=>output.push(b.toString()));
 try{
  await waitFor();
  runner=spawn(process.execPath,['tests/chiapas/frontend-eventos.e2e.mjs'],{env:{...process.env,FIESTA_E2E_URL:`http://127.0.0.1:${port}/evento-anual-amor-2026/`},stdio:'inherit'});
  const status=await new Promise((resolve,reject)=>{runner.once('error',reject);runner.once('exit',resolve)});
  process.exitCode=status??1;
 }catch(e){console.error(output.join(''));throw e;}
 finally{server.kill();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
