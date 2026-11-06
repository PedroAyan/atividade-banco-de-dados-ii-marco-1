"""Backup binario e restauracao somente em cluster isolado vazio, sem apagar dados."""
import argparse,hashlib,json,subprocess
from pathlib import Path

def run(container,*args,data=None):
 return subprocess.run(['docker','exec','-i',container,*args],input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True).stdout

def sql(container,query):return run(container,'psql','-X','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres','-At','-c',query).decode().strip()

def signature(container):
 tables=sql(container,"select tablename from pg_tables where schemaname='academico' order by tablename").splitlines()
 out={}
 for table in tables:
  assert table.replace('_','').isalnum()
  out[table]=sql(container,f"select count(*)||':'||md5(coalesce(string_agg(row_to_json(t)::text,E'\\n' order by row_to_json(t)::text),'')) from academico.{table} t")
 return out

p=argparse.ArgumentParser();p.add_argument('action',choices=['backup','restore']);p.add_argument('--container',required=True);p.add_argument('--dir',required=True);a=p.parse_args();folder=Path(a.dir)
if a.action=='backup':
 folder.mkdir(parents=True,exist_ok=False)
 dump=run(a.container,'pg_dump','-U','postgres','-d','postgres','-Fc')
 roles=run(a.container,'pg_dumpall','-U','postgres','--roles-only','--no-role-passwords').decode()
 # Conta de bootstrap ja existe em um destino novo; nao restaurar nem alterar postgres.
 roles='\n'.join(line for line in roles.splitlines() if not line.startswith(('CREATE ROLE postgres;','ALTER ROLE postgres ')))+'\n'
 (folder/'academico.dump').write_bytes(dump);(folder/'roles.sql').write_text(roles,encoding='utf-8')
 manifest={'data':signature(a.container),'sha256':{n:hashlib.sha256((folder/n).read_bytes()).hexdigest() for n in ['academico.dump','roles.sql']},'version':sql(a.container,'show server_version')}
 (folder/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
 print('Backup concluido',folder)
else:
 manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
 for name,digest in manifest['sha256'].items():assert hashlib.sha256((folder/name).read_bytes()).hexdigest()==digest,'Checksum invalido'
 assert sql(a.container,"select count(*) from pg_namespace where nspname='academico'")=='0','Destino contem schema academico'
 assert sql(a.container,"select count(*) from pg_roles where rolname !~ '^pg_' and rolname<>'postgres'")=='0','Destino contem papeis: usar cluster vazio'
 assert sql(a.container,"select count(*) from pg_tables where schemaname not in ('pg_catalog','information_schema')")=='0','Destino contem tabelas'
 assert sql(a.container,'show server_version_num')[:2]==manifest['version'].split('.')[0],'Versao principal diferente'
 run(a.container,'psql','-X','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres',data=(folder/'roles.sql').read_bytes())
 run(a.container,'pg_restore','-U','postgres','-d','postgres','--exit-on-error','--single-transaction',data=(folder/'academico.dump').read_bytes())
 # pg_dump nao preserva ACLs dos construtores gerados de tipos RANGE.
 sql(a.container,'REVOKE ALL ON ALL FUNCTIONS IN SCHEMA academico FROM PUBLIC')
 actual=signature(a.container);assert actual==manifest['data'],'Dados restaurados divergem'
 print(json.dumps({'restaurado':True,'tabelas':len(actual),'version':sql(a.container,'show server_version'),'assinaturas':actual},indent=2))
