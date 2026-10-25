// Production artifact + Chrome + real local file HTTP. No remote network/accounts.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';
const base=process.env.FIESTA_STATIC_URL;
if(!base||new URL(base).hostname!=='127.0.0.1')throw Error('Solo servidor estático localhost');
let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;};
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);}
for(const file of files('dist')){
 assert.ok(!/(?:^|\/)(?:\.env[^/]*|[^/]+\.(?:bak|sql|pem|key|log|map))$/i.test(file),'Archivo privado/de pruebas en build: '+file);
 if(/\.(?:js|html|css|svg|json)$/.test(file)){
  const content=fs.readFileSync(file,'utf8');
  assert.ok(!/sb_secret_[A-Za-z0-9_-]{20,}/.test(content),'Posible clave privada en '+file);
  for(const match of content.matchAll(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g)){
   let claims;try{claims=JSON.parse(Buffer.from(match[0].split('.')[1],'base64url').toString());}catch{continue;}
   assert.notEqual(claims.role,'service_role','service_role JWT en '+file);
  }
 }
}checks++;
for(const route of ['', 'chiapas/', 'chiapas/acceso/']){
 assert.ok(fs.existsSync(path.join('dist',route,'index.html')),'Falta HTML físico: '+route);
 const response=await fetch(base+route);eq(response.status,200);
 assert.ok((await response.text()).includes('lang="es"'));checks++;
}
eq((await fetch(base+'ruta-inexistente')).status,404);
const browser=await chromium.launch({headless:true,...(process.env.FIESTA_CHROME_PATH?{executablePath:process.env.FIESTA_CHROME_PATH}:{})});
try{
 const context=await browser.newContext();const blocked=[];
 await context.route('**/*',route=>{
  const url=route.request().url();
  if(new URL(url).origin===new URL(base).origin)return route.continue();
  blocked.push(new URL(url).origin);return route.abort();
 });
 const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 eq((await page.goto(base)).status(),200);
 await page.getByRole('button',{name:'Registrarme al evento'}).waitFor();checks++;
 const favicon=await page.locator('link[rel="icon"]').getAttribute('href');
 eq(favicon,'/evento-anual-amor-2026/favicon.svg');eq((await fetch(new URL(favicon,base))).status,200);
 await page.getByRole('link',{name:'Chiapas',exact:true}).click();
 await page.getByText('Inscripciones abiertas · Cupo de 500 participantes').waitFor();checks++;
  assert.equal(await page.getByRole('link',{name:"RADEV'S · Minatitlán",exact:true}).count(),0);checks++;
 eq((await page.reload()).status(),200);
 await page.getByText('Inscripciones abiertas · Cupo de 500 participantes').waitFor();checks++;
 await page.getByRole('button',{name:'Registrarme en Chiapas'}).click();
 await page.getByRole('heading',{name:'Registro de participantes',exact:true}).waitFor();checks++;
 eq(await page.getByText('Las inscripciones todavía no están habilitadas.',{exact:true}).count(),0);
 eq(await page.locator('button[type="submit"]:enabled').count(),0);
 eq((await page.goto(base+'chiapas/acceso')).status(),200);
 await page.getByRole('heading',{name:'Acceso AMOR',exact:true}).waitFor();checks++;
 eq((await page.reload()).status(),200);
 await page.getByRole('heading',{name:'Acceso AMOR',exact:true}).waitFor();checks++;
 eq(errors,[]);
 console.log(`${checks} comprobaciones aprobadas: build estático, enlaces/recargas Chiapas y acceso, favicon y ausencia de claves privadas detectables. Chrome real; red externa bloqueada (${blocked.length} solicitudes abortadas). Sin cuentas ni Supabase real.`);
 await context.close();
}finally{await browser.close();}
