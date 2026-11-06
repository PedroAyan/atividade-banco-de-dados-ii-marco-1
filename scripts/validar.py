"""Somente em cluster isolado novo. DSN via variável BD2_DSN."""
import os,json,time,threading
from pathlib import Path
import psycopg
DSN=os.environ['BD2_DSN']
def conn(): return psycopg.connect(DSN,autocommit=True)
def execute_file(c,name): c.execute(Path(name).read_text(encoding='utf-8'))
def save(name,value):
 Path('evidencias').mkdir(exist_ok=True)
 Path('evidencias/'+name).write_text(json.dumps(value,indent=2,default=str),encoding='utf-8')
if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('etapa',choices=['base','views','indices','concorrencia','seguranca']);a=p.parse_args()
 with conn() as c:
  if a.etapa=='base':
   assert c.execute("select to_regnamespace('academico')").fetchone()[0] is None,'Banco deve estar vazio'
   for f in ['01-create-tables','02-insert-data','03-consultas','99-validacao']:execute_file(c,'sql/'+f+'.sql')
   save('base.json',{'version':c.execute('select version()').fetchone()[0],'counts':c.execute('select (select count(*) from academico.tb_aluno),(select count(*) from academico.tb_matricula),(select count(*) from academico.tb_historico)').fetchone()})
  elif a.etapa=='views':
   execute_file(c,'sql/04-views.sql');assert c.execute('select count(*) from academico.v_historico').fetchone()[0]==360
   c.execute('REFRESH MATERIALIZED VIEW CONCURRENTLY academico.mv_indicadores')
   save('views.json',c.execute('select * from academico.mv_indicadores').fetchall())
  elif a.etapa=='indices':
   queries=["select * from academico.tb_matricula where id_turma=1 and status_matricula='MATRICULADO'","select * from academico.tb_turma where id_periodo_letivo=1","select * from academico.tb_aluno where id_curso=1","select * from academico.tb_historico where situacao_historico='REPROVADO_FALTA'"]
   c.execute('ANALYZE');r={'version':c.execute('select version()').fetchone()[0],'queries':queries}
   def plans():return [[c.execute('EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) '+q).fetchone()[0] for _ in range(7)] for q in queries]
   r['antes']=plans();execute_file(c,'sql/05-indices.sql');c.execute('ANALYZE');r['depois']=plans();save('indices.json',r)
  elif a.etapa=='concorrencia':
   if not c.execute("select to_regprocedure('academico.matricular_bloqueio(integer,integer)')").fetchone()[0]:execute_file(c,'sql/06-transacoes.sql')
   results={}
   for mode in ['anomalia','bloqueio','serializavel']:
    turma=c.execute("insert into academico.tb_turma(codigo_turma,id_disciplina,id_periodo_letivo,turno_turma,vagas_turma) values(%s,1,1,'NOTURNO',1) returning id_turma",('T_'+mode,)).fetchone()[0]
    barrier=threading.Barrier(2);out=[];observations=[]
    def worker(aluno):
     db=psycopg.connect(DSN);db.isolation_level=psycopg.IsolationLevel.SERIALIZABLE if mode=='serializavel' else psycopg.IsolationLevel.READ_COMMITTED
     try:
      # Mesmo snapshot lógico: ambos observam vaga antes de tentar inserir.
      occupied=db.execute('select count(*) from academico.tb_matricula where id_turma=%s',(turma,)).fetchone()[0]
      capacity=db.execute('select vagas_turma from academico.tb_turma where id_turma=%s',(turma,)).fetchone()[0]
      observations.append({'aluno':aluno,'ocupadas_lidas':occupied,'capacidade_lida':capacity})
      barrier.wait(timeout=15)
      assert occupied<capacity,'Precondicao do ensaio: vaga disponivel'
      if mode=='anomalia':db.execute('insert into academico.tb_matricula(id_aluno,id_turma) values(%s,%s)',(aluno,turma))
      else:db.execute('select academico.matricular_'+mode+'(%s,%s)',(aluno,turma))
      db.commit();out.append('commit')
     except psycopg.Error as e:
      db.rollback();out.append(e.sqlstate)
      if e.sqlstate=='40001':
       try:db.execute('select academico.matricular_serializavel(%s,%s)',(aluno,turma));db.commit();out.append('retry commit')
       except psycopg.Error as retry:db.rollback();out.append('retry '+retry.sqlstate)
     finally:db.close()
    start=time.perf_counter();threads=[threading.Thread(target=worker,args=(n,)) for n in [1,2]]
    for t in threads:t.start()
    for t in threads:t.join(timeout=30);assert not t.is_alive()
    count=c.execute('select count(*) from academico.tb_matricula where id_turma=%s',(turma,)).fetchone()[0]
    assert count==(2 if mode=='anomalia' else 1),(mode,out,count)
    results[mode]={'outcomes':out,'leituras_antes_da_barreira':observations,'ocupadas':count,'capacidade':1,'seconds':time.perf_counter()-start}
    c.execute('delete from academico.tb_historico where id_matricula in (select id_matricula from academico.tb_matricula where id_turma=%s)',(turma,));c.execute('delete from academico.tb_matricula where id_turma=%s',(turma,));c.execute('delete from academico.tb_turma where id_turma=%s',(turma,))
   save('concorrencia.json',results)
  elif a.etapa=='seguranca':
   execute_file(c,'sql/07-seguranca.sql')
   c.execute("create role teste_aluno login password 'isolado'; grant aluno to teste_aluno; insert into academico.identidade_aluno values('teste_aluno',1)")
   from psycopg.conninfo import make_conninfo
   with psycopg.connect(make_conninfo(DSN,user='teste_aluno',password='isolado'),autocommit=True) as db:
    own=db.execute('select count(*) from academico.v_historico where id_aluno=1').fetchone()[0];other=db.execute('select count(*) from academico.v_historico where id_aluno=2').fetchone()[0]
    assert own>0 and other==0
    db.execute("set app.id_aluno='2'")
    assert db.execute('select count(*) from academico.v_historico where id_aluno=2').fetchone()[0]==0
    denied=[]
    for sql in ['select * from academico.identidade_aluno',"update academico.tb_historico set nota_a1_historico=10",'select academico.matricular_bloqueio(2,1)']:
     try:db.execute(sql);raise AssertionError('Acesso indevido: '+sql)
     except psycopg.errors.InsufficientPrivilege:denied.append(sql)
   for role in ['secretaria','coordenacao']:
    c.execute('set role '+role);assert c.execute('select count(*) from academico.v_historico').fetchone()[0]==360;c.execute('reset role')
   for role,statement,allowed in [('secretaria',"insert into academico.tb_matricula(id_aluno,id_turma) values(1,9)",False),('secretaria',"update academico.tb_matricula set status_matricula='MATRICULADO'",False),('coordenacao',"update academico.tb_historico set nota_a1_historico=8 where id_matricula=1",True)]:
    with psycopg.connect(DSN) as probe:
     probe.execute('set role '+role)
     try:probe.execute(statement);assert allowed
     except psycopg.errors.InsufficientPrivilege:assert not allowed
     finally:probe.rollback()
   execute_file(c,'sql/03-consultas.sql')
   execute_file(c,'sql/99-validacao.sql')
   execute_file(c,'sql/98-validacao-marco2.sql')
   save('seguranca.json',{'proprios':own,'outro':other,'negados':denied,'administrativos':360,'variavel_nao_falsifica_identidade':True,'secretaria_sem_escrita_direta':True,'coordenacao_atualiza_notas':True})
 print('OK',a.etapa)
