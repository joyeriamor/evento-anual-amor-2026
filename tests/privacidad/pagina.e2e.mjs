// HTTP estático y navegador reales; servicios externos bloqueados o simulados.
// Nunca consulta Auth, Storage o registros de producción.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, stat, mkdir } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = resolve('dist');
const prefix = '/evento-anual-amor-2026/';
const mime = { '.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.png':'image/png', '.svg':'image/svg+xml' };
const server = createServer(async (req,res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (!url.pathname.startsWith(prefix)) { res.writeHead(404).end(); return; }
    let path = resolve(root, '.' + decodeURIComponent(url.pathname.slice(prefix.length - 1)));
    if (path !== root && !path.startsWith(root + sep)) { res.writeHead(403).end(); return; }
    if ((await stat(path)).isDirectory()) path = resolve(path,'index.html');
    res.writeHead(200,{'Content-Type':mime[extname(path)] || 'application/octet-stream'});
    res.end(await readFile(path));
  } catch { res.writeHead(404).end(); }
});
await new Promise((ok,fail)=>server.once('error',fail).listen(0,'127.0.0.1',ok));
const base = `http://127.0.0.1:${server.address().port}${prefix}`;
const browser = await chromium.launch({headless:true,...(process.env.FIESTA_CHROME_PATH?{executablePath:process.env.FIESTA_CHROME_PATH}:{})});
let checks=0;
const check = (actual,expected) => { assert.deepEqual(actual,expected); checks++; };
const normalized = text => text.replace(/\s+/g,' ').trim();
try {
  const direct=await fetch(base+'privacidad/'); check(direct.status,200);
  check((await direct.text()).includes('/evento-anual-amor-2026/assets/'),true);
  check((await fetch(base+'ruta-inexistente/')).status,404);
  const context=await browser.newContext();
  const backend=[]; const errors=[];
  await context.route('**/*',async route=>{
    const u=new URL(route.request().url());
    if(u.origin===new URL(base).origin)return route.continue();
    if(u.hostname==='127.0.0.1'&&u.port==='54321') {
      backend.push(u.pathname);
      return route.fulfill({json:{ok:true,asesores:[],grupos:[]},headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'}});
    }
    return route.abort();
  });
  const page=await context.newPage(); page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base+'privacidad/');
  await page.getByRole('heading',{name:'Aviso de privacidad',exact:true}).waitFor();
  check(await page.getByRole('checkbox').count(),0);
  check(backend.length,0); // La página pública no verifica sesiones ni consulta participantes.
  const full=normalized(await page.getByRole('article').innerText());
  for(const section of ['1. Responsable y contacto','2. Datos recopilados','3. Finalidades','4. Comprobantes y consentimiento','5. Custodia, acceso y proveedores','6. Conservación','7. Derechos ARCO y revocación','8. Cambios al aviso'])check(full.includes(section),true);
  check(full.includes('joyeriamor@amor.com'),true);
  check(full.includes('Guadalajara, Jalisco, México'),true);
  check(full.includes('se eliminarán una vez terminado ese evento'),true);
  check(full.includes('pendiente de concretarse antes de la apertura pública'),false);
  check(full.includes('4 de noviembre de 2026'),true);
  await page.reload(); await page.getByRole('article').waitFor();
  check(normalized(await page.getByRole('article').innerText()),full);
  await page.setViewportSize({width:390,height:844});
  check(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true);
  const screenshots=process.env.FIESTA_PRIVACIDAD_EVIDENCIA;
  if(screenshots){await mkdir(screenshots,{recursive:true});await page.screenshot({path:resolve(screenshots,'privacidad-movil.png'),fullPage:true});}
  await page.setViewportSize({width:1280,height:900});
  if(screenshots)await page.screenshot({path:resolve(screenshots,'privacidad-escritorio.png'),fullPage:true});
  for(const [suffix,button] of [['','Registrarme al evento'],['chiapas/','Registrarme en Chiapas']]) {
    await page.goto(base+suffix);
    const footer=page.locator('footer').getByRole('link',{name:'Aviso de privacidad',exact:true});
    check(await footer.getAttribute('href'),prefix+'privacidad/');
    await page.getByRole('button',{name:button,exact:true}).click();
    const required=page.getByRole('checkbox',{name:/He leído el aviso de privacidad/});
    const whatsapp=page.locator('input[name="autoriza_whatsapp"]');
    check(await required.isChecked(),false); check(await whatsapp.isChecked(),false);
    check(await required.getAttribute('required'),''); check(await whatsapp.getAttribute('required'),null);
    await page.getByRole('button',{name:'Leer aviso de privacidad completo',exact:true}).click();
    check(normalized(await page.locator('#contenido-aviso-privacidad-amor').innerText()),full);
    const name=page.locator('input:not([type]), input[type="text"]').first(); await name.fill('PRUEBA LOCAL PRIVACIDAD');
    await required.check(); check(await whatsapp.isChecked(),false);
    const popupPromise=context.waitForEvent('page');
    await page.getByRole('link',{name:'Abrir aviso de privacidad en una página independiente',exact:true}).click();
    const popup=await popupPromise; await popup.getByRole('article').waitFor();
    check(normalized(await popup.getByRole('article').innerText()),full);
    check(await name.inputValue(),'PRUEBA LOCAL PRIVACIDAD'); check(await required.isChecked(),true);
    await popup.close(); await whatsapp.check(); await required.uncheck();
    check(await whatsapp.isChecked(),true); // No hay acoplamiento entre consentimientos.
    check(await page.locator('button[type="submit"]:enabled').count(),0);
    await required.check(); await whatsapp.uncheck(); check(await required.isChecked(),true);
  }
  check(errors,[]);
  console.log(`${checks} comprobaciones de privacidad aprobadas. HTTP estático y navegador reales; backend simulado; sin envíos ni datos de producción.`);
  await context.close();
} finally { await browser.close(); await new Promise(ok=>server.close(ok)); }
