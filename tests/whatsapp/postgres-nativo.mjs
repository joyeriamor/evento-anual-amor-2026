// Real PostgreSQL, isolated temporary cluster, localhost only. No production credentials.
import os from 'node:os';import path from 'node:path';import net from 'node:net';import {spawn} from 'node:child_process';
const{default:EmbeddedPostgres}=await import(process.env.EMBEDDED_POSTGRES_MODULE||'embedded-postgres');
const probe=net.createServer();await new Promise(r=>probe.listen(0,'127.0.0.1',r));const port=probe.address().port;await new Promise(r=>probe.close(r));
const cluster=new EmbeddedPostgres({databaseDir:path.join(os.tmpdir(),'fiesta-whatsapp-pg-'+crypto.randomUUID()),
 port,user:'postgres',password:crypto.randomUUID(),persistent:true,createPostgresUser:false,autoRehydrateSymlinks:true,
 initdbFlags:['--encoding=UTF8','--locale=C'],postgresFlags:['-h','127.0.0.1'],onLog:()=>{},onError:()=>{}});
try{
 await cluster.initialise();await cluster.start();await cluster.createDatabase('fiesta_whatsapp_prueba');
 const cliente=cluster.getPgClient('fiesta_whatsapp_prueba','127.0.0.1');
 const params=cliente.connectionParameters;
 const u=new URL(`postgresql://127.0.0.1:${port}/fiesta_whatsapp_prueba`);u.username=params.user;u.password=params.password;
 const hijo=spawn(process.execPath,['tests/whatsapp/sql.integration.mjs'],{stdio:'inherit',env:{...process.env,FIESTA_WHATSAPP_PG_URL:u.toString()}});
 const code=await new Promise((r,j)=>{hijo.once('exit',r);hijo.once('error',j)});if(code!==0)process.exitCode=code??1;
}finally{await cluster.stop();}
