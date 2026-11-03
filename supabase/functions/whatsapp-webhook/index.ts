import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import {firmaValida,estadosVerificados} from '../_shared/whatsapp-webhook.ts';
const reply=(s:number,b:string)=>new Response(b,{status:s,headers:{'Cache-Control':'no-store','Content-Type':'text/plain'}});
Deno.serve(async req=>{
 // Remains dormant until a separate, authorized webhook configuration.
 if(Deno.env.get('WHATSAPP_WEBHOOK_HABILITADO')!=='true')return reply(503,'Deshabilitado');
 if(req.method==='GET'){
  const u=new URL(req.url),token=Deno.env.get('META_WEBHOOK_VERIFY_TOKEN');
  if(token&&u.searchParams.get('hub.mode')==='subscribe'&&u.searchParams.get('hub.verify_token')===token)
   return reply(200,u.searchParams.get('hub.challenge')??'');
  return reply(403,'No autorizado');
 }
 if(req.method!=='POST')return reply(405,'Método no permitido');
 try{
  const reader=req.body?.getReader();if(!reader)return reply(400,'Sin contenido');
  const partes:Uint8Array[]=[];let total=0;
  while(true){const r=await reader.read();if(r.done)break;total+=r.value.byteLength;
   if(total>262144){await reader.cancel();return reply(413,'Límite excedido');}partes.push(r.value);}
  const raw=new Uint8Array(total);let offset=0;for(const p of partes){raw.set(p,offset);offset+=p.length;}
  if(!await firmaValida(raw,req.headers.get('x-hub-signature-256')??'',Deno.env.get('META_APP_SECRET')??''))
   return reply(401,'Firma inválida');
  const numero=Deno.env.get('META_WHATSAPP_PHONE_NUMBER_ID');if(!numero)return reply(503,'Configuración incompleta');
  const estados=estadosVerificados(JSON.parse(new TextDecoder().decode(raw)),numero);
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
   {auth:{persistSession:false,autoRefreshToken:false}});
  for(const e of estados){const r=await db.rpc('whatsapp_confirmar_entrega_interno',{
   p_message_id:e.id,p_estado:e.estado,p_fecha:e.fecha});if(r.error)return reply(503,'No disponible');}
  return reply(200,'OK');
 }catch{return reply(503,'No disponible');}
});
