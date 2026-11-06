BEGIN;
CREATE INDEX ix_matricula_ativa_turma ON academico.tb_matricula(id_turma) WHERE status_matricula='MATRICULADO';
CREATE INDEX ix_turma_periodo ON academico.tb_turma(id_periodo_letivo);
CREATE INDEX ix_aluno_curso ON academico.tb_aluno(id_curso);
CREATE INDEX ix_historico_situacao ON academico.tb_historico(situacao_historico);
COMMIT;
