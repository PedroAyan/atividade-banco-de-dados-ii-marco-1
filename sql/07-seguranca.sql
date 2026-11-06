BEGIN;
-- Instalar em cluster isolado: recusa colisao de nomes de papeis existentes.
CREATE ROLE aluno NOLOGIN;
CREATE ROLE secretaria NOLOGIN;
CREATE ROLE coordenacao NOLOGIN;
REVOKE ALL ON SCHEMA academico FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA academico FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA academico FROM PUBLIC;
GRANT USAGE ON SCHEMA academico TO aluno,secretaria,coordenacao;
CREATE TABLE academico.identidade_aluno(login name PRIMARY KEY,id_aluno integer NOT NULL REFERENCES academico.tb_aluno);
REVOKE ALL ON academico.identidade_aluno FROM PUBLIC,aluno,secretaria,coordenacao;
CREATE FUNCTION academico.aluno_da_sessao() RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,academico AS $$ SELECT id_aluno FROM academico.identidade_aluno WHERE login=session_user $$;
REVOKE ALL ON FUNCTION academico.aluno_da_sessao() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION academico.aluno_da_sessao() TO aluno;
ALTER TABLE academico.tb_matricula ENABLE ROW LEVEL SECURITY;
ALTER TABLE academico.tb_historico ENABLE ROW LEVEL SECURITY;
CREATE POLICY matricula_propria ON academico.tb_matricula FOR SELECT TO aluno USING(id_aluno=academico.aluno_da_sessao());
CREATE POLICY historico_proprio ON academico.tb_historico FOR SELECT TO aluno USING(EXISTS(SELECT 1 FROM academico.tb_matricula m WHERE m.id_matricula=tb_historico.id_matricula));
CREATE POLICY matricula_admin ON academico.tb_matricula TO secretaria,coordenacao USING(true) WITH CHECK(true);
CREATE POLICY historico_admin ON academico.tb_historico TO secretaria,coordenacao USING(true) WITH CHECK(true);
GRANT SELECT ON academico.tb_matricula,academico.tb_historico,academico.v_historico,academico.v_oferta TO aluno;
GRANT SELECT ON academico.tb_turma,academico.tb_disciplina,academico.tb_periodo_letivo TO aluno;
GRANT SELECT ON ALL TABLES IN SCHEMA academico TO secretaria,coordenacao;
REVOKE ALL ON academico.identidade_aluno FROM secretaria,coordenacao;
GRANT UPDATE(nota_a1_historico,nota_a2_historico,nota_p3_historico,frequencia_historico,situacao_historico) ON academico.tb_historico TO coordenacao;
GRANT EXECUTE ON FUNCTION academico.matricular_bloqueio(integer,integer) TO secretaria;
COMMIT;
