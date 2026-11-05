const{spawn}=require('node:child_process');const path=require('node:path');const net=require('node:net');
(async()=>{const port=5184;const probe=net.createServer();await new Promise((r,j)=>probe.once('error',j).listen(port,'127.0.0.1',r));await new Promise(r=>probe.close(r));
 const server=spawn(process.execPath,[path.resolve('node_modules/vite/bin/vite.js'),'--host','127.0.0.1','--port',String(port),'--strictPort'],{env:{...process.env,VITE_SUPABASE_URL:'http://127.0.0.1:54321',VITE_SUPABASE_PUBLISHABLE_KEY:'local-test-only'},stdio:['ignore','pipe','pipe']});
 try{let ready=false;for(let n=0;n<100;n++){if(server.exitCode!==null)throw Error('Vite local terminó');try{if((await fetch(`http://127.0.0.1:${port}/evento-anual-amor-2026/`)).ok){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,100));}if(!ready)throw Error('Vite local no respondió');
  const test=spawn(process.execPath,['tests/whatsapp/ensayo-plataforma.pagina.e2e.mjs'],{env:{...process.env,FIESTA_E2E_URL:`http://127.0.0.1:${port}/evento-anual-amor-2026/`},stdio:'inherit'});
  process.exitCode=await new Promise((r,j)=>{test.once('exit',r);test.once('error',j)});
 }finally{server.kill();}
})().catch(e=>{console.error(e.message);process.exitCode=1});
