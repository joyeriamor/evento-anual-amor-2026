// Real local browser, simulated Auth/Edge HTTP. No production credentials or sends.
import assert from 'node:assert/strict';
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
const base=process.env.FIESTA_E2E_URL;
if(!base||new URL(base).hostname!=='127.0.0.1')throw Error('Solo UI local');
const browser=await chromium.launch({headless:true,...(process.env.FIESTA_CHROME_PATH?{executablePath:process.env.FIESTA_CHROME_PATH}:{})});
let checks=0;const check=(a,b)=>{assert.deepEqual(a,b);checks++;};
try{
 const context=await browser.newContext();const requests=[];const errors=[];
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());
  if(u.origin===new URL(base).origin)return route.continue();
  if(u.origin!=='http://127.0.0.1:54321')return route.abort();
  const headers={'access-control-allow-origin':'*','access-control-allow-headers':'*'};
  if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
  if(u.pathname==='/auth/v1/token'){
   const id='a1111111-1111-4111-8111-111111111111';const token='eyJhbGciOiJIUzI1NiJ9.'+Buffer.from(JSON.stringify({sub:id,exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.fixture';
   return route.fulfill({json:{access_token:token,refresh_token:'fixture',expires_in:3600,token_type:'bearer',user:{id,email:'fixture@example.test'}},headers});
  }
  if(u.pathname==='/functions/v1/whatsapp-ensayo-plataforma'){
   const body=req.postDataJSON();check(Object.keys(body).sort(),['accion','confirmar']);check(req.headers().authorization?.startsWith('Bearer '),true);requests.push(body.accion);
   if(body.accion==='procesar')await new Promise(r=>setTimeout(r,250));
   return route.fulfill({json:{ok:true,es_prueba:true,estado:body.accion==='procesar'?'aceptado':body.accion},headers});
  }
  return route.fulfill({status:404,json:{},headers});
 });
 const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
 await page.goto(base+'tests/whatsapp/ensayo-plataforma.html');
 await page.getByRole('heading',{name:'Ensayo aislado de WhatsApp'}).waitFor();
 check(await page.getByRole('button',{name:'1. Crear inscripción ficticia'}).isVisible(),false);
 await page.getByLabel('Correo administrativo').fill('fixture@example.test');await page.getByLabel('Contraseña',{exact:true}).fill('solo-fixture-local');
 await page.getByRole('button',{name:'Iniciar sesión',exact:true}).click();
 const crear=page.getByRole('button',{name:'1. Crear inscripción ficticia'});await crear.waitFor();
 check(await crear.isEnabled(),false);check(await page.getByRole('button',{name:'Consultar estado de entrega'}).isEnabled(),true);
 await page.getByRole('checkbox').check();check(await crear.isEnabled(),true);
 await crear.click();await page.getByRole('status').getByText('"estado": "crear"',{exact:false}).waitFor();
 await page.getByRole('button',{name:'2. Autorizar cortesía y emitir QR'}).click();await page.getByRole('status').getByText('"estado": "confirmar"',{exact:false}).waitFor();
 const enviar=page.getByRole('button',{name:'3. Procesar invitación por WhatsApp'});
 await enviar.dblclick();await page.getByRole('status').getByText('aceptado',{exact:false}).waitFor();
 check(await enviar.isEnabled(),false);check(requests.filter(a=>a==='procesar').length,1);
 await page.getByRole('button',{name:'Consultar estado de entrega'}).click();await page.getByRole('status').getByText('"estado": "estado"',{exact:false}).waitFor();
 check(requests.slice(0,4),['crear','confirmar','procesar','estado']);
 check(errors,[]);await context.close();
 console.log(`${checks} comprobaciones de navegador del ensayo aprobadas; Auth/Edge simulados, sin datos ni mensajes reales.`);
}finally{await browser.close();}
