// Real browser, local UI, simulated Supabase HTTP responses. Never targets production.
import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.FIESTA_E2E_URL || 'http://127.0.0.1:5173/evento-anual-amor-2026/';
if (!['127.0.0.1','localhost'].includes(new URL(base).hostname)) throw new Error('E2E permitido solo en localhost');
const browser = await chromium.launch({ headless: true, ...(process.env.FIESTA_CHROME_PATH ? { executablePath: process.env.FIESTA_CHROME_PATH } : {}) });
let checks = 0;
try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(base);
  await page.getByRole('button', { name: 'Registrarme al evento' }).waitFor(); checks++;
  await page.getByRole('link', { name: 'Chiapas', exact: true }).click();
  await page.getByText('Las inscripciones para Chiapas todavía no están habilitadas.').waitFor(); checks++;
  await page.getByRole('button', { name: 'Ver formulario de Chiapas' }).click();
  assert.equal(await page.locator('button[type="submit"]:enabled').count(),0);checks++;
  assert.deepEqual(errors, []);checks++;
  await page.close();
  for (const [suffix,event,nombre] of [
    ['', '43e67bda-d19d-4c0e-a639-e85f2d62f294', "RADEV'S"],
    ['chiapas', '3dc92160-79af-4bf7-b770-263038e88900', 'Chiapas'],
  ]) {
    const context = await browser.newContext();
    const payload = Buffer.from(JSON.stringify({ sub:'aa111111-1111-4111-8111-111111111111', exp:Math.floor(Date.now()/1000)+3600 })).toString('base64url');
    const token = `eyJhbGciOiJIUzI1NiJ9.${payload}.fixture`;
    await context.addInitScript(({token}) => localStorage.setItem('sb-127-auth-token', JSON.stringify({ access_token:token, refresh_token:'fixture-only', expires_at:Math.floor(Date.now()/1000)+3600,expires_in:3600,token_type:'bearer',user:{id:'aa111111-1111-4111-8111-111111111111',email:'local@example.test'} })),{token});
    const seen = [];
    await context.route('http://127.0.0.1:54321/**',async route=>{
      const req=route.request(); const body=req.postDataJSON();
      const name=new URL(req.url()).pathname.split('/').pop();
      if (req.method()==='OPTIONS') return route.fulfill({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'}});
      let data={id:'aa111111-1111-4111-8111-111111111111',email:'local@example.test'};
      if(req.url().includes('/functions/')) {
        seen.push({name,body}); assert.equal(body.evento_id,event);
        data=name==='verificar-personal'?{ok:true,autorizado:true,evento_id:event,usuario:{rol:'administrador'}}:
          name==='resumen-accesos'?{ok:true,resumen:{participantes:0,confirmados:0,pendientes:0,pagos_pendientes:0,ingresos:0}}:
          name==='resumen-cupo-evento'?{ok:true,cupo:{capacidad:suffix?500:1500,ocupados:0,disponibles:suffix?500:1500,con_pago:0,cortesias:0,cortesias_pendientes:0,pendientes:0,porcentaje:0}}:
          {ok:true,registros:[],total:0,pagina:1,limite:20,participantes:[]};
      }
      await route.fulfill({json:data,headers:{'access-control-allow-origin':'*'}});
    });
    const p=await context.newPage(); await p.goto(base+suffix);
    await p.getByText('local@example.test', { exact: false }).waitFor({timeout:10000});checks++;
    assert.ok((await p.locator('header').innerText()).includes(nombre));checks++;
    await p.getByRole('button',{name:'Revisar pagos',exact:true}).click();
    await p.getByRole('heading',{name:'Validación de pagos'}).waitFor();
    await p.waitForTimeout(100);
    assert.ok(seen.some(x=>x.name===(suffix?'bandejas-admin-chiapas':'bandejas-admin')));checks++;
    await context.close();
  }
  console.log(`${checks} comprobaciones E2E aprobadas. Navegador real; Supabase HTTP simulado.`);
} finally { await browser.close(); }
