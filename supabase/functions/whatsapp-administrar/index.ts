import { serveEvento } from '../_shared/evento.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{
 'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*'}});
serveEvento({roles:['administrador']},async req=>{
 try {
  const body=await req.json();
  if(!['listar','reintentar'].includes(body.accion) ||
   Object.keys(body).some(k=>!['accion','evento_id','envio_id','pagina'].includes(k)) ||
   (body.accion==='reintentar' && (typeof body.envio_id!=='string' || !/^[0-9a-f-]{36}$/i.test(body.envio_id))) ||
   (body.pagina!==undefined && (!Number.isInteger(body.pagina)||body.pagina<1||body.pagina>100000)))
   return reply({ok:false,error:'Parámetros inválidos'},400);
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
   {auth:{persistSession:false,autoRefreshToken:false}});
  const bearer=req.headers.get('authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
  const {data,error}=await db.auth.getUser(bearer);
  if(error||!data.user)return reply({ok:false},401);
  const r=await db.rpc('whatsapp_admin_interno',{p_admin:data.user.id,
   p_evento:req.headers.get('x-evento-autorizado'),p_accion:body.accion,p_envio:body.envio_id??null,p_pagina:body.pagina??1});
  if(r.error)return reply({ok:false,error:'Operación no disponible o no permitida'},409);
  return reply(r.data);
 }catch{return reply({ok:false,error:'No fue posible consultar WhatsApp'},503);}
});
