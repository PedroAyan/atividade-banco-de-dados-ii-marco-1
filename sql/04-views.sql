BEGIN;
CREATE VIEW academico.v_oferta AS
 SELECT t.*, d.nome_disciplina, p.ano_periodo_letivo, p.semestre_periodo_letivo
 FROM academico.tb_turma t JOIN academico.tb_disciplina d USING(id_disciplina)
 JOIN academico.tb_periodo_letivo p USING(id_periodo_letivo);
CREATE VIEW academico.v_vagas AS
 SELECT t.id_turma, t.vagas_turma, count(m.id_matricula) AS ocupadas,
 t.vagas_turma-count(m.id_matricula) AS disponiveis
 FROM academico.tb_turma t LEFT JOIN academico.tb_matricula m
 ON m.id_turma=t.id_turma AND m.status_matricula='MATRICULADO'
 GROUP BY t.id_turma;
CREATE VIEW academico.v_historico WITH (security_invoker=true) AS
 SELECT m.id_aluno,m.id_turma,h.* FROM academico.tb_historico h
 JOIN academico.tb_matricula m USING(id_matricula);
CREATE MATERIALIZED VIEW academico.mv_indicadores AS
 SELECT t.id_periodo_letivo, count(*) AS turmas, sum(v.ocupadas) AS matriculados,
 sum(v.disponiveis) AS vagas_disponiveis
 FROM academico.tb_turma t JOIN academico.v_vagas v USING(id_turma)
 GROUP BY t.id_periodo_letivo;
CREATE UNIQUE INDEX ON academico.mv_indicadores(id_periodo_letivo);
COMMIT;
