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
    FOREACH t IN ARRAY ARRAY['campus','curso','curriculo','disciplina',
        'curriculo_disciplina','pre_requisito','professor','sala',
        'periodo_letivo','feriado','turma','turma_horario','aluno',
        'matricula','historico','log_matricula']
    LOOP
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM academico.%I)', t)
            INTO ocupado;
        IF ocupado THEN
            RAISE EXCEPTION 'Carga cancelada: tabela % já contém dados.', t;
        END IF;
    END LOOP;
END $$;

INSERT INTO campus (nome, cidade) VALUES
    ('Asa Sul','Brasília'), ('Ceilândia','Brasília');

INSERT INTO curso (codigo,nome,grau,ch_total,campus_id)
SELECT v.codigo,v.nome,'BACHARELADO',v.ch,c.id
FROM (VALUES ('CCO','Ciência da Computação',3200),
             ('ENGC','Engenharia de Computação',3600)) v(codigo,nome,ch)
CROSS JOIN campus c WHERE c.nome='Asa Sul';
INSERT INTO curso (codigo,nome,grau,ch_total,campus_id)
SELECT 'ADS','Análise e Desenvolvimento de Sistemas','TECNOLOGO',2000,id
FROM campus WHERE nome='Asa Sul';

-- Recorte curricular sintético para alunos que ingressaram em 2025.
INSERT INTO curriculo (curso_id,ano_vigencia,ativo)
SELECT id,2025,true FROM curso;
INSERT INTO curriculo (curso_id,ano_vigencia,ativo)
SELECT id,2023,false FROM curso WHERE codigo='CCO';

INSERT INTO disciplina (codigo,nome,ch_teorica,ch_pratica,ementa) VALUES
 ('HMDC253','Banco de Dados I',30,30,'Modelagem relacional e fundamentos de SQL.'),
 ('CCO072','Banco de Dados II',30,30,'Transações, consultas avançadas e administração.'),
 ('CCO085','Programação Paralela',45,15,'Concorrência e paralelismo.'),
 ('MDC050','Inteligência Artificial',45,15,'Busca e representação do conhecimento.'),
 ('ADS033','Aprendizagem de Máquina',30,30,'Aprendizado supervisionado e não supervisionado.'),
 ('MDC118','Algoritmos e Programação de Computadores I',30,30,'Lógica e programação.'),
 ('MDC122','Sistemas Operacionais',45,15,'Processos, memória e sistemas de arquivos.');

INSERT INTO curriculo_disciplina (curriculo_id,disciplina_id,periodo,tipo)
SELECT c.id,d.id,
    CASE d.codigo WHEN 'MDC118' THEN 1 WHEN 'HMDC253' THEN 2 ELSE 3 END,
    CASE WHEN d.codigo IN ('ADS033','MDC050') THEN 'OPTATIVA'::tipo_disc_t
         ELSE 'OBRIGATORIA'::tipo_disc_t END
FROM curriculo c CROSS JOIN disciplina d;

INSERT INTO pre_requisito (disciplina_id,requisito_id,vinculo)
SELECT d.id,r.id,'PRE_REQUISITO'
FROM (VALUES ('HMDC253','MDC118'), ('CCO072','HMDC253'),
             ('CCO085','MDC118'), ('CCO085','MDC122'),
             ('MDC050','MDC118')) v(disciplina,requisito)
JOIN disciplina d ON d.codigo=v.disciplina
JOIN disciplina r ON r.codigo=v.requisito;

INSERT INTO professor (matricula,nome,email,titulacao) VALUES
 ('201680','Rodrigo Gonçalves Pinto','rodrigo.pinto@iesb.edu.br','MESTRE'),
 ('201455','Marcelo Paiva','marcelo.paiva@iesb.edu.br','DOUTOR'),
 ('201322','Roger Santos','roger.santos@iesb.edu.br','MESTRE');

INSERT INTO sala (campus_id,codigo,capacidade,tipo)
SELECT c.id,v.codigo,v.capacidade,v.tipo::tipo_sala_t
FROM (VALUES ('JB1',55,'LABORATORIO'),('JB2/4',36,'LABORATORIO'),
             ('JB5',44,'LABORATORIO'),('IA2',24,'LABORATORIO'),
             ('IA3',30,'LABORATORIO'),('JA2',32,'TEORICA')) v(codigo,capacidade,tipo)
CROSS JOIN campus c WHERE c.nome='Asa Sul';

INSERT INTO periodo_letivo (ano,semestre,data_inicio,data_fim) VALUES
 (2025,2,'2025-08-04','2025-12-13'),
 (2026,1,'2026-02-02','2026-06-20'),
 (2026,2,'2026-08-03','2026-12-12');

INSERT INTO feriado (data,descricao,campus_id) VALUES
 ('2026-09-07','Independência do Brasil',NULL),
 ('2026-10-12','Nossa Senhora Aparecida',NULL),
 ('2026-11-02','Finados',NULL),
 ('2026-11-15','Proclamação da República',NULL),
 ('2026-11-20','Dia da Consciência Negra',NULL),
 ('2026-12-25','Natal',NULL);

-- Quatro turmas históricas fictícias, com 60 vagas cada.
INSERT INTO turma (codigo,disciplina_id,periodo_letivo_id,professor_id,turno,vagas)
SELECT v.codigo,d.id,p.id,pr.id,v.turno::turno_t,60
FROM (VALUES ('APC25-M','MDC118',2025,2,'MATUTINO'),
             ('APC25-N','MDC118',2025,2,'NOTURNO'),
             ('BDI26-M','HMDC253',2026,1,'MATUTINO'),
             ('BDI26-N','HMDC253',2026,1,'NOTURNO')) v(codigo,disc,ano,semestre,turno)
JOIN disciplina d ON d.codigo=v.disc
JOIN periodo_letivo p ON (p.ano,p.semestre)=(v.ano,v.semestre)
CROSS JOIN professor pr WHERE pr.matricula='201455';

-- Seis turmas da oferta fornecida pelo professor.
INSERT INTO turma (codigo,disciplina_id,periodo_letivo_id,professor_id,turno,vagas)
SELECT v.codigo,d.id,p.id,pr.id,v.turno::turno_t,v.vagas
FROM (VALUES ('CCODM2B','CCO072','MATUTINO',40),
             ('CCONM2B','CCO072','NOTURNO',24),
             ('CCODM3B','CCO085','MATUTINO',30),
             ('CCONM3B','CCO085','NOTURNO',30),
             ('ENGCDM2B','MDC050','MATUTINO',36),
             ('ADSDM2C','ADS033','MATUTINO',36)) v(codigo,disc,turno,vagas)
JOIN disciplina d ON d.codigo=v.disc
CROSS JOIN periodo_letivo p
JOIN professor pr ON pr.matricula = CASE
    WHEN v.disc='CCO072' THEN '201680'
    WHEN v.disc='CCO085' THEN '201455'
    ELSE '201322'
END
WHERE p.ano=2026 AND p.semestre=2;

-- Horários apenas da oferta atual. Turmas históricas não recebem horários:
-- a exclusão do DDL fornecido não distingue semestres.
INSERT INTO turma_horario (turma_id,sala_id,dia_semana,faixa)
SELECT t.id,s.id,v.dia,v.faixa::timerange
FROM (VALUES ('CCODM2B','JB1',2,'[08:15,11:00)'),
             ('CCONM2B','IA2',2,'[19:15,22:00)'),
             ('CCODM3B','IA3',5,'[08:15,11:00)'),
             ('CCONM3B','IA3',5,'[19:15,22:00)'),
             ('ENGCDM2B','JB2/4',4,'[08:15,11:00)'),
             ('ADSDM2C','JB2/4',6,'[08:15,11:00)')) v(turma,sala,dia,faixa)
JOIN turma t ON t.codigo=v.turma
JOIN sala s ON s.codigo=v.sala
JOIN campus c ON c.id=s.campus_id AND c.nome='Asa Sul';

-- 120 alunos distintos. O CPF é um identificador fictício de 11 dígitos,
-- não um documento real; o DDL valida formato, não dígitos verificadores.
INSERT INTO aluno (matricula,nome,cpf,email,nascimento,curso_id,curriculo_id,ingresso)
SELECT '2025'||lpad(g::text,4,'0'),
       'Aluno '||lpad(g::text,3,'0'),lpad(g::text,11,'0'),
       'aluno'||g||'@example.com', DATE '2002-01-01'+g*7,
       c.id,cr.id,DATE '2025-08-04'
FROM generate_series(1,120) g
JOIN curso c ON c.codigo=CASE WHEN g<=60 THEN 'CCO' WHEN g<=90 THEN 'ENGC' ELSE 'ADS' END
JOIN curriculo cr ON cr.curso_id=c.id AND cr.ano_vigencia=2025;

-- Uma matrícula por aluno em cada semestre: 120 × 3 = 360.
-- As duas turmas de Programação Paralela ficam vazias: nenhum aluno tem
-- aprovação em Sistemas Operacionais. Isso também permite testar LEFT JOIN.
INSERT INTO matricula (aluno_id,turma_id,data_matricula,status)
SELECT a.id,t.id,p.data_inicio::timestamp AT TIME ZONE 'America/Sao_Paulo','MATRICULADO'
FROM aluno a CROSS JOIN periodo_letivo p
JOIN turma t ON t.periodo_letivo_id=p.id
WHERE t.codigo=CASE
 WHEN p.ano=2025 THEN CASE WHEN right(a.matricula,4)::integer<=60 THEN 'APC25-M' ELSE 'APC25-N' END
 WHEN p.semestre=1 THEN CASE WHEN right(a.matricula,4)::integer<=60 THEN 'BDI26-M' ELSE 'BDI26-N' END
 WHEN right(a.matricula,4)::integer<=36 THEN 'CCODM2B'
 WHEN right(a.matricula,4)::integer<=60 THEN 'CCONM2B'
 WHEN right(a.matricula,4)::integer<=90 THEN 'ENGCDM2B'
 ELSE 'ADSDM2C' END;

-- Notas determinísticas, com empates para ranking e variação entre períodos.
-- Todos aprovam APC e BD I antes de cursar as disciplinas de 2026/2.
INSERT INTO historico (matricula_id,nota_a1,nota_a2,nota_p3,frequencia,situacao)
SELECT m.id,
 CASE WHEN p.ano=2025 THEN 5.0+(g.n%11)*0.4
      WHEN p.semestre=1 THEN 5.5+((g.n+3)%10)*0.4
      ELSE 2.0+(g.n%17)*0.5 END,
 CASE WHEN p.ano=2025 THEN 6.0+((g.n+2)%9)*0.4
      WHEN p.semestre=1 THEN 5.0+((g.n+5)%11)*0.4
      ELSE 2.0+((g.n+4)%17)*0.5 END,
 CASE WHEN p.ano=2026 AND p.semestre=2 AND g.n%7=0 THEN 7.0 ELSE NULL END,
 CASE WHEN p.ano=2026 AND p.semestre=2 AND g.n%10=0 THEN 65 ELSE 80+(g.n%21) END,
 'CURSANDO'
FROM matricula m JOIN aluno a ON a.id=m.aluno_id
JOIN turma t ON t.id=m.turma_id JOIN periodo_letivo p ON p.id=t.periodo_letivo_id
CROSS JOIN LATERAL (SELECT right(a.matricula,4)::integer AS n) g;

-- A média é gerada pelo banco. A situação é derivada dela e da frequência.
UPDATE historico SET situacao=CASE
 WHEN frequencia<75 THEN 'REPROVADO_FALTA'::situacao_t
 WHEN media_final>=5 THEN 'APROVADO'::situacao_t
 ELSE 'REPROVADO_NOTA'::situacao_t END;

-- Auditoria explícita da carga; não representa um gatilho de auditoria.
INSERT INTO log_matricula (matricula_id,acao,detalhe)
SELECT id,'CARGA_INICIAL',jsonb_build_object('origem','02-insert-data.sql')
FROM matricula;

-- Verificações essenciais: em caso de inconsistência a transação é desfeita.
DO $$
BEGIN
 IF (SELECT count(*) FROM aluno)<>120
 OR (SELECT count(*) FROM turma)<>10
 OR (SELECT count(*) FROM matricula)<>360
 OR (SELECT count(*) FROM historico)<>360 THEN
   RAISE EXCEPTION 'Quantidades da carga diferentes das esperadas.';
 END IF;
 IF EXISTS (SELECT 1 FROM turma t JOIN matricula m ON m.turma_id=t.id
            WHERE m.status='MATRICULADO' GROUP BY t.id,t.vagas HAVING count(*)>t.vagas) THEN
   RAISE EXCEPTION 'Existe turma acima do limite de vagas.';
 END IF;
END $$;
COMMIT;

SELECT 'alunos' AS tabela,count(*) AS quantidade FROM academico.aluno
UNION ALL SELECT 'turmas',count(*) FROM academico.turma
UNION ALL SELECT 'matriculas',count(*) FROM academico.matricula
UNION ALL SELECT 'historicos',count(*) FROM academico.historico;
