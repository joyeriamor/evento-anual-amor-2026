export async function firmaValida(raw:Uint8Array,firma:string,secret:string):Promise<boolean>{
 if(!secret || !/^sha256=[a-f0-9]{64}$/.test(firma))return false;
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
 const bytes=new Uint8Array(firma.slice(7).match(/../g)!.map(x=>parseInt(x,16)));
 return crypto.subtle.verify('HMAC',key,bytes,new Uint8Array(raw));
}
export function estadosVerificados(body:unknown,numero:string):{id:string;estado:string;fecha:string}[]{
 const salida:{id:string;estado:string;fecha:string}[]=[];
 if(!body || typeof body!=='object')return salida;
 const b=body as {object?:unknown;entry?:unknown};if(b.object!=='whatsapp_business_account'||!Array.isArray(b.entry))return salida;
 for(const e of b.entry){if(!e||!Array.isArray(e.changes))continue;for(const c of e.changes){
  if(c?.field!=='messages'||c.value?.metadata?.phone_number_id!==numero||!Array.isArray(c.value.statuses))continue;
  for(const s of c.value.statuses){
   if(!s||typeof s!=='object')continue;
   if(typeof s.id!=='string'||!s.id.startsWith('wamid.')||s.id.length>255||!['delivered','read','failed'].includes(s.status)||
    typeof s.timestamp!=='string'||!/^\d{10}$/.test(s.timestamp))continue;
   const ms=Number(s.timestamp)*1000;if(ms>Date.now()+300000)continue;
   salida.push({id:s.id,estado:s.status,fecha:new Date(ms).toISOString()});

  }
 }}return salida;
}
