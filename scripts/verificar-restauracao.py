import os,json
from pathlib import Path
import psycopg
from psycopg.conninfo import make_conninfo
source=os.environ['BD2_DSN'];dest=os.environ['BD2_RESTORE_DSN']
with psycopg.connect(source,autocommit=True) as a,psycopg.connect(dest,autocommit=True) as b:
 queries={
 'indices':"select indexname,indexdef from pg_indexes where schemaname='academico' order by 1",
 'policies':"select tablename,policyname,roles,cmd,qual,with_check from pg_policies where schemaname='academico' order by 1,2",
 'views':"select viewname,definition from pg_views where schemaname='academico' order by 1",
 'functions':"select p.proname,pg_get_functiondef(p.oid),p.proacl::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='academico' and p.prokind='f' order by p.proname,pg_get_function_identity_arguments(p.oid)",
 'acl':"select relname,coalesce(relacl,acldefault(CASE WHEN relkind='S' THEN 's'::\"char\" ELSE 'r'::\"char\" END,relowner))::text,relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='academico' order by 1",
 'column_grants':"select table_name,column_name,grantee,privilege_type from information_schema.column_privileges where table_schema='academico' order by 1,2,3,4",
 'memberships':"select r.rolname,m.rolname from pg_auth_members am join pg_roles r on r.oid=am.roleid join pg_roles m on m.oid=am.member order by 1,2",
 'sequences':"select sequencename,last_value from pg_sequences where schemaname='academico' order by 1"}
 for label,q in queries.items():assert a.execute(q).fetchall()==b.execute(q).fetchall(),label
 b.execute("alter role teste_aluno password 'isolado'")
with psycopg.connect(make_conninfo(dest,user='teste_aluno',password='isolado'),autocommit=True) as b:
 own=b.execute('select count(*) from academico.v_historico where id_aluno=1').fetchone()[0]
 other=b.execute('select count(*) from academico.v_historico where id_aluno=2').fetchone()[0]
 assert own==3 and other==0
r={'catalogos_comparados':list(queries),'historicos_proprios':own,'historicos_alheios':other}
Path('evidencias/restauracao-seguranca.json').write_text(json.dumps(r,indent=2),encoding='utf-8');print(r)
