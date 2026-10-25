// Serve the production build as files, without an SPA/404 fallback. Localhost only.
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const {spawn}=require('node:child_process');
const root=path.resolve('dist'),base='/evento-anual-amor-2026/';
const types={'.html':'text/html; charset=utf-8','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png'};
const server=http.createServer((req,res)=>{
 try{
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405);return res.end();}
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(!pathname.startsWith(base)){res.writeHead(404);return res.end();}
  let file=path.resolve(root,pathname.slice(base.length));
  if(file!==root&&!file.startsWith(root+path.sep)){res.writeHead(403);return res.end();}
  if(fs.existsSync(file)&&fs.statSync(file).isDirectory()){
   if(!pathname.endsWith('/')){res.writeHead(301,{location:pathname+'/'});return res.end();}
   file=path.join(file,'index.html');
  }
  if(!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);return res.end();}
  res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store'});
  if(req.method==='HEAD')return res.end();
  fs.createReadStream(file).pipe(res);
 }catch{res.writeHead(400);res.end();}
});
(async()=>{
 await new Promise((resolve,reject)=>server.once('error',reject).listen(0,'127.0.0.1',resolve));
 try{
  const runner=spawn(process.execPath,[path.resolve(__dirname,'../tests/chiapas/pages-estatico.e2e.mjs')],{stdio:'inherit',env:{...process.env,FIESTA_STATIC_URL:`http://127.0.0.1:${server.address().port}${base}`}});
  process.exitCode=await new Promise((resolve,reject)=>{runner.once('error',reject);runner.once('exit',code=>resolve(code??1));});
 }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e.message);server.close();process.exitCode=1;});
