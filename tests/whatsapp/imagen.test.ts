import { generarImagen } from '../../supabase/functions/_shared/whatsapp-imagen.ts';
import jsQR from 'npm:jsqr@1.4.0';
import { PNG } from 'npm:pngjs@7.0.0';
import { Buffer } from 'node:buffer';
Deno.test('PNG real: decodifica exactamente el token ficticio vigente',async()=>{
 const token='TOKEN_FICTICIO_SIN_VALIDEZ_REAL_20261103_1234567890';
 const bytes=await generarImagen({elegible:true,invitacion_id:'ficticia',registro_id:'ficticio',
 evento_id:'3dc92160-79af-4bf7-b770-263038e88900',token_qr:token,telefono:'529611234567',
 folio:'FICTICIO-SIN-VALIDEZ',participante:'PARTICIPANTE FICTICIA DE ENSAYO',evento:'Fiesta Anual AMOR 2026',
 fecha:'19 de diciembre de 2026',recepcion:'Por confirmar',lugar:'Salón BIANCO, Tuxtla Gutiérrez, Chiapas'});
 const png=PNG.sync.read(Buffer.from(bytes));
 if(png.width!==1122||png.height!==1402)throw Error('Dimensiones inesperadas');
 const rgba=new Uint8ClampedArray(354*354*4);
 for(let y=0;y<354;y++)for(let x=0;x<354;x++)for(let c=0;c<4;c++)
  rgba[(y*354+x)*4+c]=png.data[((y+743)*png.width+x+384)*4+c];
 // jsqr exposes CommonJS default interop differently in Deno type declarations.
 const leer=jsQR as unknown as (data:Uint8ClampedArray,width:number,height:number)=>{data:string}|null;
 const leido=leer(rgba,354,354);
 if(leido?.data!==token)throw Error('El QR no corresponde al token vigente');
});
