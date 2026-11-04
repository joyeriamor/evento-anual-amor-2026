import QRCode from "npm:qrcode@1.5.4";
import { svgDesign, pngFromPublicAsset } from "../_shared/whatsapp-imagen.ts";
import { render } from "jsr:@nick/resvg@0.1.0-rc.1";
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const EVENTOS: Record<string,{ rpc:string; lugar:string; horario:string }> = {
  "43e67bda-d19d-4c0e-a639-e85f2d62f294": {
    rpc:"emitir_invitacion_admin_interna",
    lugar:"Salón RADEV'S 1 · Minatitlán, Veracruz",
    horario:"Recepción: 1:00 p.m.",
  },
  "3dc92160-79af-4bf7-b770-263038e88900": {
    rpc:"emitir_invitacion_chiapas_interna",
    lugar:"SALÓN BIANCO · Tuxtla Gutiérrez, Chiapas",
    horario:"Horario por confirmar",
  },
};
const ORIGINS = new Set(["https://joyeriamor.github.io","http://localhost:5173"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function headers(origin:string):Record<string,string> {
  return {
    "Cache-Control":"private, no-store, max-age=0","Pragma":"no-cache",
    "X-Content-Type-Options":"nosniff","Access-Control-Allow-Methods":"POST, OPTIONS",
    "Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info, x-supabase-api-version",
    ...(ORIGINS.has(origin)?{"Access-Control-Allow-Origin":origin,"Vary":"Origin"}:{}),
  };
}
function json(status:number, data:Record<string,unknown>,origin:string):Response {
  return new Response(JSON.stringify(data),{
    status,headers:{...headers(origin),"Content-Type":"application/json; charset=utf-8"},
  });
}
Deno.serve(async(req:Request)=>{
  const origin=req.headers.get("origin")??"";
  if(origin && !ORIGINS.has(origin))return json(403,{ok:false,error:"Origen no permitido"},origin);
  if(req.method==="OPTIONS")return json(200,{ok:true},origin);
  if(req.method!=="POST")return json(405,{ok:false,error:"Método no permitido"},origin);
  if(!req.headers.get("content-type")?.toLowerCase().startsWith("application/json"))
    return json(415,{ok:false,error:"Se requiere JSON"},origin);
  const token=req.headers.get("authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if(!token)return json(401,{ok:false,error:"Sesión requerida"},origin);
  const url=Deno.env.get("SUPABASE_URL"),secret=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!url || !secret)return json(503,{ok:false,error:"Configuración incompleta"},origin);
  try {
    const raw=await req.text();
    if(raw.length>1024)return json(413,{ok:false,error:"Solicitud demasiado grande"},origin);
    let body:unknown;
    try{body=JSON.parse(raw)}catch{return json(400,{ok:false,error:"JSON inválido"},origin)}
    if(!body || typeof body!=="object" || Array.isArray(body))
      return json(400,{ok:false,error:"Formato inválido"},origin);
    const values=body as Record<string,unknown>;
    if(Object.keys(values).length!==1 || typeof values.registro_id!=="string" ||
      !UUID.test(values.registro_id))
      return json(400,{ok:false,error:"registro_id inválido"},origin);
    const db=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data:identity,error:authError}=await db.auth.getUser(token);
    if(authError || !identity.user)return json(401,{ok:false,error:"Sesión inválida"},origin);
    const adminId=identity.user.id;
    const {data:admin,error:adminError}=await db.from("usuarios")
      .select("rol,activo").eq("id",adminId).maybeSingle();
    if(adminError)return json(503,{ok:false,error:"No se pudo verificar la cuenta"},origin);
    if(!admin?.activo || admin.rol!=="administrador")
      return json(403,{ok:false,error:"Operación exclusiva de administradores"},origin);
    const {data:registro,error:regError}=await db.from("registros")
      .select("id,evento_id,promotora_id,folio,estado,es_prueba,exento_pago")
      .eq("id",values.registro_id).maybeSingle();
    if(regError)return json(503,{ok:false,error:"No se pudo consultar el registro"},origin);
    if(!registro)return json(404,{ok:false,error:"Registro no encontrado"},origin);
    const ev=EVENTOS[registro.evento_id];
    if(!ev || registro.estado!=="confirmado" || registro.es_prueba===true)
      return json(409,{ok:false,error:"La inscripción no está confirmada"},origin);
    const {data:permiso,error:permisoError}=await db.from("usuarios_eventos")
      .select("usuario_id").eq("usuario_id",adminId)
      .eq("evento_id",registro.evento_id).eq("activo",true).maybeSingle();
    if(permisoError)return json(503,{ok:false,error:"No se pudo revisar el evento"},origin);
    if(!permiso)return json(403,{ok:false,error:"Sin acceso al evento"},origin);
    if(!registro.exento_pago) {
      const {data:pago,error:pagoError}=await db.from("pagos")
        .select("id").eq("registro_id",registro.id).eq("estado","validado").maybeSingle();
      if(pagoError)return json(503,{ok:false,error:"No se pudo comprobar el pago"},origin);
      if(!pago)return json(409,{ok:false,error:"Sin pago validado ni cortesía"},origin);
    }
    const {data:inv,error:invError}=await db.from("invitaciones")
      .select("id,token_vault_id").eq("registro_id",registro.id)
      .in("estado",["activa","emitida"]).order("emitida_at",{ascending:false}).limit(1).maybeSingle();
    if(invError)return json(503,{ok:false,error:"No se pudo consultar el QR"},origin);
    if(!inv?.token_vault_id)return json(409,{ok:false,error:"No existe un QR original recuperable"},origin);

    const [p,e]=await Promise.all([
      db.from("promotoras").select("nombres,apellidos").eq("id",registro.promotora_id).maybeSingle(),
      db.from("eventos").select("fecha_inicio").eq("id",registro.evento_id).maybeSingle(),
    ]);
    if(p.error || e.error || !p.data || !e.data?.fecha_inicio)
      return json(503,{ok:false,error:"No se pudieron consultar los datos del evento"},origin);

    // Una RPC ya existente comprueba el hash en Vault. Nunca reemitimos aquí.
    const {data:issued,error:issuedError}=await db.rpc("whatsapp_qr_admin_interno",{
      p_invitacion:inv.id,p_admin:adminId,
    });
    if(issuedError)return json(503,{ok:false,error:"No se pudo recuperar el QR original"},origin);
    const qr=issued as {invitacion_id?:unknown;ya_existia?:unknown;token_qr?:unknown}|null;
    if(!qr || qr.invitacion_id!==inv.id || qr.ya_existia!==true ||
      typeof qr.token_qr!=="string" || qr.token_qr.length<16 || qr.token_qr.length>1024)
      return json(409,{ok:false,error:"QR vigente no recuperable"},origin);

    const fecha=new Date(e.data.fecha_inicio);
    if(!Number.isFinite(fecha.getTime()))
      return json(503,{ok:false,error:"Fecha del evento no válida"},origin);
    const fechaTexto=new Intl.DateTimeFormat("es-MX",{
      timeZone:"America/Mexico_City",day:"numeric",month:"long",year:"numeric",
    }).format(fecha);
    const nombre=([p.data.nombres,p.data.apellidos].filter(Boolean).join(" ")||"PARTICIPANTE")
      .trim().slice(0,120).toLocaleUpperCase("es-MX");
    const folio=String(registro.folio??"SIN FOLIO").slice(0,70);
    const qrSvg=await QRCode.toString(qr.token_qr,{
      type:"svg",width:354,margin:4,errorCorrectionLevel:"H",
      color:{dark:"#000000",light:"#FFFFFFFF"},
    });
    const [background,logo]=await Promise.all([
      pngFromPublicAsset("invitacion-amor-navidad-fondo.png"),
      pngFromPublicAsset("amor-logo.png"),
    ]);
    const composed=svgDesign({
      background,logo,qr:qrSvg,nombre,folio,fecha:fechaTexto,
      lugar:ev.lugar,horario:ev.horario,
    });
    const png=render(composed);
    if(!png || png.length<200 || png.length>8_000_000 ||
      png[0]!==0x89 || png[1]!==0x50 || png[2]!==0x4e || png[3]!==0x47)
      return json(503,{ok:false,error:"No se pudo generar el PNG"},origin);
    // No se guarda un archivo público ni se invoca WhatsApp/Meta.
    return new Response(new Uint8Array(png),{
      status:200,headers:{
        ...headers(origin),"Content-Type":"image/png",
        "Content-Length":String(png.length),
        "Content-Disposition":'attachment; filename="invitacion-amor-'+inv.id+'.png"',
      },
    });
  } catch(e) {
    console.error("Generar invitación PNG:",e instanceof Error?e.name:"error");
    return json(503,{ok:false,error:"No se pudo crear la invitación"},origin);
  }
});
