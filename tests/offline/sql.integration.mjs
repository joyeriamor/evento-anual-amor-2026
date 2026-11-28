import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const A='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
const B='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
const E='43e67bda-d19d-4c0e-a639-e85f2d62f294';
const C='3dc92160-79af-4bf7-b770-263038e88900';
const device=randomUUID(), otherDevice=randomUUID();
const hash=s=>createHash('sha256').update(s).digest('hex');
let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;};
const no=async(fn,pattern)=>{await assert.rejects(fn,pattern);checks++;};
const user=async id=>db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);
const rpc=async(fn,args)=>(await db.query('select public.'+fn+'('+args.map((_,i)=>'$'+(i+1)).join(',')+') as r',args)).rows[0].r;
try {
 await db.exec(`
 create role anon;create role authenticated;create role service_role;
 create schema auth;
 create function auth.uid() returns uuid language sql as
 $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create table usuarios(id uuid primary key,rol text,activo boolean);
 create table usuarios_eventos(usuario_id uuid,evento_id uuid,activo boolean);
 create table eventos(id uuid primary key,fecha_inicio timestamptz);
 create table promotoras(id uuid primary key,nombres text,apellidos text,tipo_participante text,foto_path text);
 create table asesores(id uuid primary key,nombre text);
 create table registros(id uuid primary key,evento_id uuid,promotora_id uuid,asesor_id uuid,folio text,
 estado text,grupo_ruta text,exento_pago boolean,es_prueba boolean);
 create table invitaciones(id uuid primary key,registro_id uuid references registros(id),token_hash text unique,
 estado text,emitida_at timestamptz);
 create table pagos(registro_id uuid,estado text);
 create table accesos(id uuid primary key default gen_random_uuid(),invitacion_id uuid not null references invitaciones(id),
 operador_id uuid not null,ingresado_at timestamptz not null);
 `);
 await db.exec(await readFile('supabase/migrations/20261128025528_acceso_offline.sql','utf8'));
 await db.query("insert into usuarios values($1,'administrador',true),($2,'acceso',true)",[A,B]);
 await db.query("insert into eventos values($1,now()+interval '1 day'),($2,now()+interval '2 days')",[E,C]);
 await db.query('insert into usuarios_eventos values($1,$2,true),($3,$4,true)',[A,E,B,C]);
 const data=[];
 for(let i=0;i<9;i++) {
  const registro=randomUUID(),inv=randomUUID(),token=String(i+1).repeat(64);
  data.push({registro,inv,token});
  await db.query("insert into registros values($1,$2,null,null,$3,'confirmado',null,true,false)",[registro,E,'F-'+i]);
  await db.query("insert into invitaciones values($1,$2,$3,'emitida',now())",[inv,registro,hash(token)]);
 }
 await db.query("insert into registros select gen_random_uuid(),$1,null,null,'EXTRA-'||n,'pendiente',null,false,false from generate_series(1,1100) n",[E]);
 await db.query("insert into registros values(gen_random_uuid(),$1,null,null,'CHI','pendiente',null,false,false)",[C]);
 await db.query("insert into registros values(gen_random_uuid(),$1,null,null,'DEMO','confirmado',null,true,true)",[E]);
 await user(A);
 const p=await rpc('offline_descargar',[E,device]);
 eq(p.participantes.length,1109);
 eq(p.evento_id,E);eq(p.usuario_id,A);eq(p.dispositivo_id,device);
 eq(p.participantes.every(x=>x.evento_id===E),true);
 eq(p.participantes.some(x=>x.folio==='DEMO'),false);
 eq(p.participantes.every(x=>!('token' in x) && !('telefono' in x)),true);
 await no(()=>rpc('offline_descargar',[C,device]),/Sin permiso/);
 await no(()=>rpc('offline_descargar',[randomUUID(),device]),/Sin permiso/);
 await no(()=>rpc('offline_descargar',[E,null]),/Equipo requerido/);
 const now=new Date().toISOString(), op=randomUUID();
 const sync=(t,operation=randomUUID(),time=now,d=device,paq=p.paquete_id,ev=E)=>
  rpc('offline_sincronizar',[ev,d,paq,operation,t,time]);
 const first=await sync(data[0].token,op);
 eq(first.estado,'ingreso_registrado');
 eq(await sync(data[0].token,op),first);
 eq((await sync(data[0].token)).estado,'ya_ingreso');
 eq((await db.query('select count(*)::integer as n from accesos')).rows[0].n,1);
 await no(()=>sync(data[1].token,op),/reutilizado/);
 await no(()=>sync(data[0].token,op,'2001-01-01T00:00:00Z'),/reutilizado/);
 await no(()=>sync(data[1].token,randomUUID(),now,otherDevice),/no pertenece/);
 eq((await sync('f'.repeat(64))).estado,'qr_fuera_del_paquete');
 await no(()=>sync('invalido'),/inválida/);
 eq((await sync(data[1].token,randomUUID(),'2001-01-01T00:00:00Z')).estado,'fecha_fuera_de_rango');
 eq((await sync(data[1].token,randomUUID(),'2099-01-01T00:00:00Z')).estado,'fecha_fuera_de_rango');
 await db.query("update registros set exento_pago=false where id=$1",[data[1].registro]);
 eq((await sync(data[1].token)).estado,'sin_pago');
 await db.query("insert into pagos values($1,'validado')",[data[1].registro]);
 eq((await sync(data[1].token)).estado,'ingreso_registrado');
 await db.query("update invitaciones set estado='revocada' where id=$1",[data[2].inv]);
 eq((await sync(data[2].token)).estado,'no_autorizado_actualmente');
 await db.query("update registros set estado='cancelado' where id=$1",[data[3].registro]);
 eq((await sync(data[3].token)).estado,'no_autorizado_actualmente');
 const nuevaToken='a'.repeat(64);
 await db.query("insert into invitaciones values($1,$2,$3,'emitida',now())",[randomUUID(),data[4].registro,hash(nuevaToken)]);
 eq((await sync(nuevaToken)).estado,'qr_fuera_del_paquete');
 await user(B);
 await no(()=>sync(data[5].token),/Sin permiso/);
 const c=await rpc('offline_descargar',[C,device]);eq(c.participantes.length,1);
 await no(()=>rpc('offline_sincronizar',[C,device,p.paquete_id,randomUUID(),data[5].token,now]),/no pertenece/);
 await db.query('insert into usuarios_eventos values($1,$2,true)',[B,E]);
 await no(()=>sync(data[5].token),/no pertenece/);
 await user(A);
 await db.query("update usuarios set activo=false where id=$1",[A]);
 await no(()=>sync(data[5].token),/Sin permiso/);
 await db.query("update usuarios set activo=true,rol='recepcion' where id=$1",[A]);
 await no(()=>rpc('offline_descargar',[E,device]),/Sin permiso/);
 await db.query("update usuarios set rol='administrador' where id=$1",[A]);
 await db.query('update usuarios_eventos set activo=false where usuario_id=$1',[A]);
 await no(()=>sync(data[5].token),/Sin permiso/);
 await db.query('update usuarios_eventos set activo=true where usuario_id=$1',[A]);
 await user('');
 await no(()=>rpc('offline_descargar',[E,device]),/Sin permiso/);
 const permissions=(await db.query(`select
 has_table_privilege('authenticated','public.offline_paquetes','SELECT') as lectura,
 has_function_privilege('anon','public.offline_descargar(uuid,uuid)','EXECUTE') as anon,
 has_function_privilege('authenticated','public.offline_descargar(uuid,uuid)','EXECUTE') as auth,
 has_function_privilege('authenticated','public.offline_autorizar(uuid)','EXECUTE') as interna`)).rows[0];
 eq(permissions,{lectura:false,anon:false,auth:true,interna:false});
 await db.exec(await readFile('supabase/rollbacks/20261128025528_acceso_offline.sql','utf8'));
 eq((await db.query('select count(*)::integer as n from accesos')).rows[0].n,2);
 eq((await db.query("select to_regclass('public.offline_paquetes') as t")).rows[0].t,null);
 console.log(checks+' comprobaciones SQL offline aprobadas; PostgreSQL local con datos ficticios, sin producción.');
} finally { await db.close(); }
