BEGIN TRANSACTION READ ONLY;
DO $$
BEGIN
 IF (SELECT count(*) FROM academico.v_oferta) <> 10 THEN RAISE EXCEPTION 'Oferta inesperada'; END IF;
 IF (SELECT count(*) FROM academico.tb_matricula) <> 360 THEN RAISE EXCEPTION 'Carga de matriculas alterada'; END IF;
 IF (SELECT count(*) FROM academico.v_historico) <> 360 THEN RAISE EXCEPTION 'Historico inesperado'; END IF;
 IF EXISTS(SELECT 1 FROM academico.v_vagas WHERE disponiveis<0) THEN RAISE EXCEPTION 'Superlotacao'; END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='academico.tb_historico'::regclass) THEN RAISE EXCEPTION 'RLS desligado'; END IF;
 IF has_function_privilege('aluno','academico.matricular_bloqueio(integer,integer)','EXECUTE') THEN RAISE EXCEPTION 'Aluno pode matricular'; END IF;
 IF has_table_privilege('secretaria','academico.tb_matricula','INSERT') THEN RAISE EXCEPTION 'Secretaria pode contornar lock'; END IF;
END $$;
SELECT 'Marco 2: estrutura, carga e privilegios basicos OK' AS resultado;
COMMIT;
