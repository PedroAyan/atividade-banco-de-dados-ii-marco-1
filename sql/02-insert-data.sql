-- Marco 1 — Carga didática e determinística para PostgreSQL 17.
-- Executar após 01-create-tables.sql, uma vez, com as tabelas vazias.
-- 120 alunos + 10 turmas (6 em 2026/2) + 360 matrículas + 360 históricos.
-- Alunos, CPFs, notas, currículos de apoio e turmas antigas são fictícios.
-- Disciplinas e oferta de 2026/2 seguem os dados fornecidos pelo professor.
-- As notas de 2026/2 simulam o fim do semestre, não a data atual.
BEGIN;
SET LOCAL search_path TO academico, public;

-- Evita misturar a carga com dados já existentes. Não apaga registros.
DO $$
DECLARE t text; ocupado boolean;
BEGIN
    FOREACH t IN ARRAY ARRAY['tb_campus','tb_curso','tb_curriculo','tb_disciplina',
        'tb_curriculo_disciplina','tb_pre_requisito','tb_professor','tb_sala',
        'tb_periodo_letivo','tb_feriado','tb_turma','tb_turma_horario','tb_aluno',
        'tb_matricula','tb_historico','tb_log_matricula']
    LOOP
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM academico.%I)', t)
            INTO ocupado;
        IF ocupado THEN
            RAISE EXCEPTION 'Carga cancelada: tabela % já contém dados.', t;
        END IF;
    END LOOP;
END $$;

INSERT INTO tb_campus (nome_campus, cidade_campus) VALUES
    ('Asa Sul','Brasília'), ('Ceilândia','Brasília');

INSERT INTO tb_curso (codigo_curso,nome_curso,grau_curso,ch_total_curso,id_campus)
SELECT v.codigo,v.nome,'BACHARELADO',v.ch,c.id_campus
FROM (VALUES ('CCO','Ciência da Computação',3200),
             ('ENGC','Engenharia de Computação',3600)) v(codigo,nome,ch)
CROSS JOIN tb_campus c WHERE c.nome_campus='Asa Sul';
INSERT INTO tb_curso (codigo_curso,nome_curso,grau_curso,ch_total_curso,id_campus)
SELECT 'ADS','Análise e Desenvolvimento de Sistemas','TECNOLOGO',2000,id_campus
FROM tb_campus WHERE nome_campus='Asa Sul';

-- Recorte curricular sintético para alunos que ingressaram em 2025.
INSERT INTO tb_curriculo (id_curso,ano_vigencia_curriculo,ativo_curriculo)
SELECT id_curso,2025,true FROM tb_curso;
INSERT INTO tb_curriculo (id_curso,ano_vigencia_curriculo,ativo_curriculo)
SELECT id_curso,2023,false FROM tb_curso WHERE codigo_curso='CCO';

INSERT INTO tb_disciplina (codigo_disciplina,nome_disciplina,ch_teorica_disciplina,ch_pratica_disciplina,ementa_disciplina) VALUES
 ('HMDC253','Banco de Dados I',30,30,'Modelagem relacional e fundamentos de SQL.'),
 ('CCO072','Banco de Dados II',30,30,'Transações, consultas avançadas e administração.'),
 ('CCO085','Programação Paralela',45,15,'Concorrência e paralelismo.'),
 ('MDC050','Inteligência Artificial',45,15,'Busca e representação do conhecimento.'),
 ('ADS033','Aprendizagem de Máquina',30,30,'Aprendizado supervisionado e não supervisionado.'),
 ('MDC118','Algoritmos e Programação de Computadores I',30,30,'Lógica e programação.'),
 ('MDC122','Sistemas Operacionais',45,15,'Processos, memória e sistemas de arquivos.');

INSERT INTO tb_curriculo_disciplina (id_curriculo,id_disciplina,periodo_curriculo_disciplina,tipo_curriculo_disciplina)
SELECT c.id_curriculo,d.id_disciplina,
    CASE d.codigo_disciplina WHEN 'MDC118' THEN 1 WHEN 'HMDC253' THEN 2 ELSE 3 END,
    CASE WHEN d.codigo_disciplina IN ('ADS033','MDC050') THEN 'OPTATIVA'::tipo_disc_t
         ELSE 'OBRIGATORIA'::tipo_disc_t END
FROM tb_curriculo c CROSS JOIN tb_disciplina d;

INSERT INTO tb_pre_requisito (id_disciplina,id_requisito,vinculo_pre_requisito)
SELECT d.id_disciplina,r.id_disciplina,'PRE_REQUISITO'
FROM (VALUES ('HMDC253','MDC118'), ('CCO072','HMDC253'),
             ('CCO085','MDC118'), ('CCO085','MDC122'),
             ('MDC050','MDC118')) v(disciplina,requisito)
JOIN tb_disciplina d ON d.codigo_disciplina=v.disciplina
JOIN tb_disciplina r ON r.codigo_disciplina=v.requisito;

INSERT INTO tb_professor (matricula_professor,nome_professor,email_professor,titulacao_professor) VALUES
 ('201680','Rodrigo Gonçalves Pinto','rodrigo.pinto@iesb.edu.br','MESTRE'),
 ('201455','Marcelo Paiva','marcelo.paiva@iesb.edu.br','DOUTOR'),
 ('201322','Roger Santos','roger.santos@iesb.edu.br','MESTRE');

INSERT INTO tb_sala (id_campus,codigo_sala,capacidade_sala,tipo_sala)
SELECT c.id_campus,v.codigo,v.capacidade,v.tipo::tipo_sala_t
FROM (VALUES ('JB1',55,'LABORATORIO'),('JB2/4',36,'LABORATORIO'),
             ('JB5',44,'LABORATORIO'),('IA2',24,'LABORATORIO'),
             ('IA3',30,'LABORATORIO'),('JA2',32,'TEORICA')) v(codigo,capacidade,tipo)
CROSS JOIN tb_campus c WHERE c.nome_campus='Asa Sul';

INSERT INTO tb_periodo_letivo (ano_periodo_letivo,semestre_periodo_letivo,data_inicio_periodo_letivo,data_fim_periodo_letivo) VALUES
 (2025,2,'2025-08-04','2025-12-13'),
 (2026,1,'2026-02-02','2026-06-20'),
 (2026,2,'2026-08-03','2026-12-12');

INSERT INTO tb_feriado (data_feriado,descricao_feriado,id_campus) VALUES
 ('2026-09-07','Independência do Brasil',NULL),
 ('2026-10-12','Nossa Senhora Aparecida',NULL),
 ('2026-11-02','Finados',NULL),
 ('2026-11-15','Proclamação da República',NULL),
 ('2026-11-20','Dia da Consciência Negra',NULL),
 ('2026-12-25','Natal',NULL);

-- Quatro turmas históricas fictícias, com 60 vagas cada.
INSERT INTO tb_turma (codigo_turma,id_disciplina,id_periodo_letivo,id_professor,turno_turma,vagas_turma)
SELECT v.codigo,d.id_disciplina,p.id_periodo_letivo,pr.id_professor,v.turno::turno_t,60
FROM (VALUES ('APC25-M','MDC118',2025,2,'MATUTINO'),
             ('APC25-N','MDC118',2025,2,'NOTURNO'),
             ('BDI26-M','HMDC253',2026,1,'MATUTINO'),
             ('BDI26-N','HMDC253',2026,1,'NOTURNO')) v(codigo,disc,ano,semestre,turno)
JOIN tb_disciplina d ON d.codigo_disciplina=v.disc
JOIN tb_periodo_letivo p ON (p.ano_periodo_letivo,p.semestre_periodo_letivo)=(v.ano,v.semestre)
CROSS JOIN tb_professor pr WHERE pr.matricula_professor='201455';

-- Seis turmas da oferta fornecida pelo professor.
INSERT INTO tb_turma (codigo_turma,id_disciplina,id_periodo_letivo,id_professor,turno_turma,vagas_turma)
SELECT v.codigo,d.id_disciplina,p.id_periodo_letivo,pr.id_professor,v.turno::turno_t,v.vagas
FROM (VALUES ('CCODM2B','CCO072','MATUTINO',40),
             ('CCONM2B','CCO072','NOTURNO',24),
             ('CCODM3B','CCO085','MATUTINO',30),
             ('CCONM3B','CCO085','NOTURNO',30),
             ('ENGCDM2B','MDC050','MATUTINO',36),
             ('ADSDM2C','ADS033','MATUTINO',36)) v(codigo,disc,turno,vagas)
JOIN tb_disciplina d ON d.codigo_disciplina=v.disc
CROSS JOIN tb_periodo_letivo p
JOIN tb_professor pr ON pr.matricula_professor = CASE
    WHEN v.disc='CCO072' THEN '201680'
    WHEN v.disc='CCO085' THEN '201455'
    ELSE '201322'
END
WHERE p.ano_periodo_letivo=2026 AND p.semestre_periodo_letivo=2;

-- Horários apenas da oferta atual. Turmas históricas não recebem horários:
-- a exclusão do DDL fornecido não distingue semestres.
INSERT INTO tb_turma_horario (id_turma,id_sala,dia_semana_turma_horario,faixa_turma_horario)
SELECT t.id_turma,s.id_sala,v.dia,v.faixa::timerange
FROM (VALUES ('CCODM2B','JB1',2,'[08:15,11:00)'),
             ('CCONM2B','IA2',2,'[19:15,22:00)'),
             ('CCODM3B','IA3',5,'[08:15,11:00)'),
             ('CCONM3B','IA3',5,'[19:15,22:00)'),
             ('ENGCDM2B','JB2/4',4,'[08:15,11:00)'),
             ('ADSDM2C','JB2/4',6,'[08:15,11:00)')) v(turma,sala,dia,faixa)
JOIN tb_turma t ON t.codigo_turma=v.turma
JOIN tb_sala s ON s.codigo_sala=v.sala
JOIN tb_campus c ON c.id_campus=s.id_campus AND c.nome_campus='Asa Sul';

-- 120 alunos distintos. O CPF é um identificador fictício de 11 dígitos,
-- não um documento real; o DDL valida formato, não dígitos verificadores.
INSERT INTO tb_aluno (matricula_aluno,nome_aluno,cpf_aluno,email_aluno,nascimento_aluno,id_curso,id_curriculo,ingresso_aluno)
SELECT '2025'||lpad(g::text,4,'0'),
       'Aluno '||lpad(g::text,3,'0'),lpad(g::text,11,'0'),
       'aluno'||g||'@example.com', DATE '2002-01-01'+g*7,
       c.id_curso,cr.id_curriculo,DATE '2025-08-04'
FROM generate_series(1,120) g
JOIN tb_curso c ON c.codigo_curso=CASE WHEN g<=60 THEN 'CCO' WHEN g<=90 THEN 'ENGC' ELSE 'ADS' END
JOIN tb_curriculo cr ON cr.id_curso=c.id_curso AND cr.ano_vigencia_curriculo=2025;

-- Uma matrícula por aluno em cada semestre: 120 × 3 = 360.
-- As duas turmas de Programação Paralela ficam vazias: nenhum aluno tem
-- aprovação em Sistemas Operacionais. Isso também permite testar LEFT JOIN.
INSERT INTO tb_matricula (id_aluno,id_turma,data_matricula,status_matricula)
SELECT a.id_aluno,t.id_turma,p.data_inicio_periodo_letivo::timestamp AT TIME ZONE 'America/Sao_Paulo','MATRICULADO'
FROM tb_aluno a CROSS JOIN tb_periodo_letivo p
JOIN tb_turma t ON t.id_periodo_letivo=p.id_periodo_letivo
WHERE t.codigo_turma=CASE
 WHEN p.ano_periodo_letivo=2025 THEN CASE WHEN right(a.matricula_aluno,4)::integer<=60 THEN 'APC25-M' ELSE 'APC25-N' END
 WHEN p.semestre_periodo_letivo=1 THEN CASE WHEN right(a.matricula_aluno,4)::integer<=60 THEN 'BDI26-M' ELSE 'BDI26-N' END
 WHEN right(a.matricula_aluno,4)::integer<=36 THEN 'CCODM2B'
 WHEN right(a.matricula_aluno,4)::integer<=60 THEN 'CCONM2B'
 WHEN right(a.matricula_aluno,4)::integer<=90 THEN 'ENGCDM2B'
 ELSE 'ADSDM2C' END;

-- Notas determinísticas, com empates para ranking e variação entre períodos.
-- Todos aprovam APC e BD I antes de cursar as disciplinas de 2026/2.
INSERT INTO tb_historico (id_matricula,nota_a1_historico,nota_a2_historico,nota_p3_historico,frequencia_historico,situacao_historico)
SELECT m.id_matricula,
 CASE WHEN p.ano_periodo_letivo=2025 THEN 5.0+(g.n%11)*0.4
      WHEN p.semestre_periodo_letivo=1 THEN 5.5+((g.n+3)%10)*0.4
      ELSE 2.0+(g.n%17)*0.5 END,
 CASE WHEN p.ano_periodo_letivo=2025 THEN 6.0+((g.n+2)%9)*0.4
      WHEN p.semestre_periodo_letivo=1 THEN 5.0+((g.n+5)%11)*0.4
      ELSE 2.0+((g.n+4)%17)*0.5 END,
 CASE WHEN p.ano_periodo_letivo=2026 AND p.semestre_periodo_letivo=2 AND g.n%7=0 THEN 7.0 ELSE NULL END,
 CASE WHEN p.ano_periodo_letivo=2026 AND p.semestre_periodo_letivo=2 AND g.n%10=0 THEN 65 ELSE 80+(g.n%21) END,
 'CURSANDO'
FROM tb_matricula m JOIN tb_aluno a ON a.id_aluno=m.id_aluno
JOIN tb_turma t ON t.id_turma=m.id_turma JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
CROSS JOIN LATERAL (SELECT right(a.matricula_aluno,4)::integer AS n) g;

-- A média é gerada pelo banco. A situação é derivada dela e da frequência.
UPDATE tb_historico SET situacao_historico=CASE
 WHEN frequencia_historico<75 THEN 'REPROVADO_FALTA'::situacao_t
 WHEN media_final_historico>=5 THEN 'APROVADO'::situacao_t
 ELSE 'REPROVADO_NOTA'::situacao_t END;

-- Auditoria explícita da carga; não representa um gatilho de auditoria.
INSERT INTO tb_log_matricula (id_matricula,acao_log_matricula,detalhe_log_matricula)
SELECT id_matricula,'CARGA_INICIAL',jsonb_build_object('origem','02-insert-data.sql')
FROM tb_matricula;

-- Verificações essenciais: em caso de inconsistência a transação é desfeita.
DO $$
BEGIN
 IF (SELECT count(*) FROM tb_aluno)<>120
 OR (SELECT count(*) FROM tb_turma)<>10
 OR (SELECT count(*) FROM tb_matricula)<>360
 OR (SELECT count(*) FROM tb_historico)<>360 THEN
   RAISE EXCEPTION 'Quantidades da carga diferentes das esperadas.';
 END IF;
 IF EXISTS (SELECT 1 FROM tb_turma t JOIN tb_matricula m ON m.id_turma=t.id_turma
            WHERE m.status_matricula='MATRICULADO' GROUP BY t.id_turma,t.vagas_turma HAVING count(*)>t.vagas_turma) THEN
   RAISE EXCEPTION 'Existe turma acima do limite de vagas.';
 END IF;
END $$;
COMMIT;

SELECT 'alunos' AS tabela,count(*) AS quantidade FROM academico.tb_aluno
UNION ALL SELECT 'turmas',count(*) FROM academico.tb_turma
UNION ALL SELECT 'matriculas',count(*) FROM academico.tb_matricula
UNION ALL SELECT 'historicos',count(*) FROM academico.tb_historico;
