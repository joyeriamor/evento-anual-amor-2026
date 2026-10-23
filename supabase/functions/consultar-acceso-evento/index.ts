import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS'};
function json(data:unknown,status=200){return new Response(JSON.stringify(data),{status,headers:{...cors,'Content-Type':'application/json'}})}
Deno.serve(async req=>{
  if(req.method==='OPTIONS')return new Response(null,{headers:cors});
  if(req.method!=='POST')return json({ok:false,error:'Método no permitido'},405);
  try {
    const url=Deno.env.get('SUPABASE_URL')!;
    const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
    const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const bearer=req.headers.get('authorization')||'';
    if(!bearer.startsWith('Bearer '))return json({ok:false,error:'No autenticado'},401);
    const auth=createClient(url,anon,{global:{headers:{Authorization:bearer}}});
    const {data:{user},error:authError}=await auth.auth.getUser();
    if(authError||!user)return json({ok:false,error:'Sesión inválida'},401);
    const admin=createClient(url,service);
    const {data:perfil}=await admin.from('usuarios').select('rol,activo').eq('id',user.id).single();
    if(!perfil?.activo||!['administrador','acceso'].includes(perfil.rol))return json({ok:false,error:'Sin permiso'},403);
    const {token,evento_id:eventoId}=await req.json();

    const eventosPermitidos = [
      "43e67bda-d19d-4c0e-a639-e85f2d62f294",
      "3dc92160-79af-4bf7-b770-263038e88900"
    ];

    if (!eventosPermitidos.includes(eventoId)) {
      return new Response(
        JSON.stringify({
          ok:false,
          error:"Evento no valido"
        }),
        {
          status:400,
          headers:{"Content-Type":"application/json"}
        }
      );
    };
    if(typeof token!=='string'|| !/^[a-fA-F0-9]{64}$/.test(token))return json({ok:true,ficha:{ok:false,estado:'qr_invalido'}});
    const {data:ficha,error}=await auth.rpc('consultar_qr_acceso_evento',{
      p_token:token,
      p_evento_id:eventoId
    });
    if(error)throw error;
    if(!ficha?.ok)return json({ok:true,ficha});
    const {data:registro}=await admin.from('registros').select('promotora_id,asesor_id').eq('id',ficha.registro_id).single();
    if(!registro)return json({ok:false,error:'Registro inexistente'},404);
    const {data:promotora}=await admin.from('promotoras').select('nombres,apellidos,telefono_whatsapp,foto_path').eq('id',registro.promotora_id).single();
    let asesor='';
    if(registro.asesor_id){const {data:a}=await admin.from('asesores').select('*').eq('id',registro.asesor_id).single();asesor=a?.nombre || a?.nombres || '';}
    let foto_url:string|null=null;
    if(promotora?.foto_path){
      // Configurar FOTO_BUCKET con el bucket privado real de fotografías.
      const bucket=Deno.env.get('FOTO_BUCKET');
      if(bucket){const {data}=await admin.storage.from(bucket).createSignedUrl(promotora.foto_path,120);foto_url=data?.signedUrl||null;}
    }
    return json({ok:true,ficha:{...ficha,nombre:[promotora?.nombres,promotora?.apellidos].filter(Boolean).join(' '),telefono:promotora?.telefono_whatsapp,asesor,foto_url}});
  }catch(e){console.error('Error en consultar-acceso:', e instanceof Error ? e.message : String(e));return json({ok:false,error:'No fue posible consultar el QR. Intenta de nuevo.'},500)}
});
