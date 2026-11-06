BEGIN;
-- READ COMMITTED: lock da turma antes de contar; o segundo comando vê commits recentes.
CREATE FUNCTION academico.matricular_bloqueio(p_aluno integer,p_turma integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,academico AS $$
DECLARE capacidade integer; ocupacao integer; nova integer;
BEGIN
 IF current_setting('transaction_isolation') <> 'read committed' THEN
 RAISE EXCEPTION 'Usar READ COMMITTED'; END IF;
 SELECT vagas_turma INTO STRICT capacidade FROM academico.tb_turma WHERE id_turma=p_turma FOR UPDATE;
 SELECT count(*) INTO ocupacao FROM academico.tb_matricula WHERE id_turma=p_turma AND status_matricula='MATRICULADO';
 IF ocupacao>=capacidade THEN RAISE EXCEPTION 'Turma lotada' USING ERRCODE='P0001'; END IF;
 INSERT INTO academico.tb_matricula(id_aluno,id_turma) VALUES(p_aluno,p_turma) RETURNING id_matricula INTO nova;
 INSERT INTO academico.tb_historico(id_matricula) VALUES(nova);
 RETURN nova;
END $$;
CREATE FUNCTION academico.matricular_serializavel(p_aluno integer,p_turma integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,academico AS $$
DECLARE capacidade integer; ocupacao integer; nova integer;
BEGIN
 IF current_setting('transaction_isolation') <> 'serializable' THEN
 RAISE EXCEPTION 'Usar SERIALIZABLE'; END IF;
 SELECT vagas_turma INTO STRICT capacidade FROM academico.tb_turma WHERE id_turma=p_turma;
 SELECT count(*) INTO ocupacao FROM academico.tb_matricula WHERE id_turma=p_turma AND status_matricula='MATRICULADO';
 IF ocupacao>=capacidade THEN RAISE EXCEPTION 'Turma lotada' USING ERRCODE='P0001'; END IF;
 INSERT INTO academico.tb_matricula(id_aluno,id_turma) VALUES(p_aluno,p_turma) RETURNING id_matricula INTO nova;
 INSERT INTO academico.tb_historico(id_matricula) VALUES(nova);
 RETURN nova;
END $$;
REVOKE ALL ON FUNCTION academico.matricular_bloqueio(integer,integer),academico.matricular_serializavel(integer,integer) FROM PUBLIC;
COMMIT;
