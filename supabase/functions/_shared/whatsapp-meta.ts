import { cuerpoPlantilla,type Contexto,type Transporte } from './whatsapp-motor.ts';
/** No public URLs. Upload bytes to Meta and reference the returned media id. */
export function transporteMeta(token:string,numero:string,version:string,http:typeof fetch=fetch):Transporte {
 if(!token || !/^[0-9]{5,30}$/.test(numero) || !/^v[0-9]{2}\.0$/.test(version))throw new Error('configuracion_meta');
 const root=`https://graph.facebook.com/${version}`;
 async function peticion(path:string,init:RequestInit) {
  const r=await http(root+path,{...init,redirect:'error',signal:AbortSignal.timeout(20000),
   headers:{...init.headers,Authorization:`Bearer ${token}`}});
  if(!r.ok)throw new Error('meta_rechazo');
  const body=await r.json();return body;
 }
 return {
  async cargar(png) {
   if(png.length>5_000_000)throw new Error('imagen_demasiado_grande');
   const form=new FormData();form.set('messaging_product','whatsapp');form.set('type','image/png');
   form.set('file',new Blob([new Uint8Array(png)],{type:'image/png'}),'invitacion.png');
   const body=await peticion(`/${numero}/media`,{method:'POST',body:form});
   if(typeof body.id!=='string' || !/^[0-9]{1,40}$/.test(body.id))throw new Error('media_invalido');
   return body.id;
  },
  async enviar(c:Contexto,media) {
   const body=await peticion(`/${numero}/messages`,{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify(cuerpoPlantilla(c,media))});
   const id=body.messages?.[0]?.id;
   if(typeof id!=='string' || !id.startsWith('wamid.') || id.length>255)throw new Error('mensaje_invalido');
   return {id};
  },
  async eliminar(media) {
   if(!/^[0-9]{1,40}$/.test(media))throw new Error('media_invalido');
   const body=await peticion(`/${media}`,{method:'DELETE'});
   if(body.success!==true)throw new Error('media_no_eliminado');
  },
 };
}
