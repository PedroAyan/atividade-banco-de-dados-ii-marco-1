-- Marco 1 — 10 consultas de complexidade crescente.
-- PostgreSQL 17. Executar após 01-create-tables.sql e 02-insert-data.sql.
-- Somente leitura: não modifica os dados carregados.
BEGIN READ ONLY;
SET LOCAL search_path TO academico, public;

-- 01. Alunos ativos: projeção, filtro e ordenação.
-- Objetivo: listar os alunos ativos e sua data de ingresso.
SELECT matricula_aluno, nome_aluno, email_aluno, ingresso_aluno
FROM tb_aluno
WHERE ativo_aluno
ORDER BY matricula_aluno;

-- 02. Oferta de disciplinas: junções internas e junção opcional com professor.
-- Objetivo: listar as seis turmas de 2026/2 e seu responsável.
-- LEFT JOIN preserva turmas cujo id_professor seja NULL.
SELECT t.codigo_turma AS turma, d.codigo_disciplina AS disciplina, d.nome_disciplina,
       p.ano_periodo_letivo, p.semestre_periodo_letivo, t.turno_turma,
       pr.nome_professor AS professor, t.vagas_turma
FROM tb_turma t
JOIN tb_disciplina d ON d.id_disciplina=t.id_disciplina
JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
LEFT JOIN tb_professor pr ON pr.id_professor=t.id_professor
WHERE p.ano_periodo_letivo=2026 AND p.semestre_periodo_letivo=2
ORDER BY d.codigo_disciplina,t.codigo_turma;

-- 03. Histórico detalhado: junção de múltiplas tabelas.
-- Objetivo: consultar as notas e a situação do aluno de matrícula 20250001.
-- Use a matrícula pública, sem depender do valor gerado para tb_aluno.id_aluno.
SELECT a.matricula_aluno,a.nome_aluno,p.ano_periodo_letivo,p.semestre_periodo_letivo,
       d.codigo_disciplina,d.nome_disciplina AS disciplina,
       h.nota_a1_historico,h.nota_a2_historico,h.nota_p3_historico,
       h.media_final_historico,h.frequencia_historico,h.situacao_historico
FROM tb_aluno a
JOIN tb_matricula m ON m.id_aluno=a.id_aluno
JOIN tb_turma t ON t.id_turma=m.id_turma
JOIN tb_disciplina d ON d.id_disciplina=t.id_disciplina
JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
JOIN tb_historico h ON h.id_matricula=m.id_matricula
WHERE a.matricula_aluno='20250001'
ORDER BY p.ano_periodo_letivo,p.semestre_periodo_letivo,d.codigo_disciplina;

-- 04. Junção externa com agregação — requisito obrigatório.
-- Objetivo: mostrar ocupação e vagas restantes, inclusive em turmas vazias.
-- COUNT(m.id_matricula), em vez de COUNT(*), não conta a linha artificial do LEFT JOIN.
-- O filtro de status fica no ON para preservar as turmas sem matrículas ativas.
SELECT p.ano_periodo_letivo,p.semestre_periodo_letivo,t.codigo_turma,
       d.nome_disciplina AS disciplina,t.vagas_turma,
       count(m.id_matricula) AS ocupadas,t.vagas_turma-count(m.id_matricula) AS restantes
FROM tb_turma t
JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
JOIN tb_disciplina d ON d.id_disciplina=t.id_disciplina
LEFT JOIN tb_matricula m ON m.id_turma=t.id_turma AND m.status_matricula='MATRICULADO'
GROUP BY p.ano_periodo_letivo,p.semestre_periodo_letivo,t.id_turma,t.codigo_turma,
         d.nome_disciplina,t.vagas_turma
ORDER BY p.ano_periodo_letivo,p.semestre_periodo_letivo,t.codigo_turma;

-- 05. Agregação com HAVING: cursos com pelo menos 30 alunos ativos.
-- Objetivo: filtrar grupos depois da contagem, em vez de filtrar linhas.
SELECT c.codigo_curso,c.nome_curso,count(a.id_aluno) AS alunos_ativos
FROM tb_curso c JOIN tb_aluno a ON a.id_curso=c.id_curso
WHERE a.ativo_aluno
GROUP BY c.id_curso,c.codigo_curso,c.nome_curso
HAVING count(a.id_aluno)>=30
ORDER BY alunos_ativos DESC,c.codigo_curso;

-- 06. Subconsulta correlacionada com NOT EXISTS.
-- Objetivo: disciplinas do currículo do aluno ainda sem aprovação.
-- DISTINCT evita repetir uma disciplina cursada em várias turmas/períodos.
-- Esta consulta não avalia pré-requisitos; a consulta 08 faz essa verificação.
SELECT DISTINCT d.codigo_disciplina,d.nome_disciplina,
       cd.periodo_curriculo_disciplina,cd.tipo_curriculo_disciplina
FROM tb_aluno a
JOIN tb_curriculo_disciplina cd ON cd.id_curriculo=a.id_curriculo
JOIN tb_disciplina d ON d.id_disciplina=cd.id_disciplina
WHERE a.matricula_aluno='20250001'
  AND NOT EXISTS (
      SELECT 1 FROM tb_matricula m
      JOIN tb_turma t ON t.id_turma=m.id_turma
      JOIN tb_historico h ON h.id_matricula=m.id_matricula
      WHERE m.id_aluno=a.id_aluno AND t.id_disciplina=d.id_disciplina
        AND m.status_matricula='MATRICULADO' AND h.situacao_historico='APROVADO'
  )
ORDER BY cd.periodo_curriculo_disciplina,d.codigo_disciplina;

-- 07. Árvore recursiva de pré-requisitos — requisito obrigatório.
-- Objetivo: mostrar a cadeia de dependências de Banco de Dados II (CCO072).
-- Âncora: a própria disciplina, nível zero. Passo: seguir cada pré-requisito.
-- O array visitados impede revisitar um vértice no mesmo caminho: a consulta
-- termina mesmo se houver um ciclo indireto. Não há corte arbitrário de nível.
-- Filtra PRE_REQUISITO: co-requisitos não são exigências de aprovação anterior.
WITH RECURSIVE cadeia AS (
    SELECT d.id_disciplina,d.codigo_disciplina,d.nome_disciplina,0 AS nivel,
           ARRAY[d.id_disciplina] AS visitados,d.codigo_disciplina::text AS caminho
    FROM tb_disciplina d WHERE d.codigo_disciplina='CCO072'
    UNION ALL
    SELECT r.id_disciplina,r.codigo_disciplina,r.nome_disciplina,c.nivel+1,
           c.visitados||r.id_disciplina,c.caminho||' -> '||r.codigo_disciplina
    FROM cadeia c
    JOIN tb_pre_requisito pr ON pr.id_disciplina=c.id_disciplina
                            AND pr.vinculo_pre_requisito='PRE_REQUISITO'
    JOIN tb_disciplina r ON r.id_disciplina=pr.id_requisito
    WHERE NOT r.id_disciplina=ANY(c.visitados)
)
SELECT nivel,codigo_disciplina,nome_disciplina,caminho
FROM cadeia ORDER BY caminho;

-- 08. Disciplinas que um aluno já pode cursar — requisito recursivo obrigatório.
-- Recorte temporal: a consulta responde o que o aluno pode cursar NO INÍCIO do
-- semestre-alvo. Todo o julgamento usa apenas fatos anteriores a esse início.
-- Critério: pertence ao currículo, ainda não foi aprovada em período anterior e
-- TODOS os pré-requisitos diretos e indiretos foram aprovados em período
-- letivo estritamente anterior ao alvo
-- (pl.data_fim_periodo_letivo < data_inicio_periodo_letivo do alvo).
-- Uma disciplina em que o aluno JÁ ESTÁ matriculado no próprio semestre-alvo
-- não é "nova elegibilidade" e é excluída, qualquer que seja o resultado final
-- simulado dessa matrícula. A carga preenche as notas de 2026/2 como se o
-- semestre já tivesse terminado; sem essa exclusão a disciplina em curso
-- reapareceria como elegível para o semestre em que ela está sendo cursada.
-- Resultado = elegibilidade por currículo/pré-requisitos; não promete oferta,
-- vagas ou compatibilidade de horários. A carga não contém co-requisitos.
-- Se houver co-requisitos, o resultado os sinaliza para validação conjunta.
-- Ciclos são sinalizados e bloqueiam a elegibilidade da disciplina afetada.
-- Parâmetros: matrícula 20250001 e semestre-alvo 2026/2.
WITH RECURSIVE
parametros AS (
    SELECT a.id_aluno,a.id_curriculo,p.id_periodo_letivo,p.data_inicio_periodo_letivo
    FROM tb_aluno a CROSS JOIN tb_periodo_letivo p
    WHERE a.matricula_aluno='20250001'
      AND p.ano_periodo_letivo=2026 AND p.semestre_periodo_letivo=2
),
-- Aprovações válidas como pré-requisito: só períodos encerrados ANTES do
-- início do semestre-alvo. O próprio semestre-alvo nunca entra aqui.
aprovadas AS (
    SELECT DISTINCT t.id_disciplina
    FROM parametros p
    JOIN tb_matricula m ON m.id_aluno=p.id_aluno
    JOIN tb_turma t ON t.id_turma=m.id_turma
    JOIN tb_periodo_letivo pl ON pl.id_periodo_letivo=t.id_periodo_letivo
    JOIN tb_historico h ON h.id_matricula=m.id_matricula
    WHERE m.status_matricula='MATRICULADO' AND h.situacao_historico='APROVADO'
      AND pl.data_fim_periodo_letivo<p.data_inicio_periodo_letivo
),
candidatas AS (
    SELECT d.id_disciplina,d.codigo_disciplina,d.nome_disciplina,
           cd.periodo_curriculo_disciplina
    FROM parametros p
    JOIN tb_curriculo_disciplina cd ON cd.id_curriculo=p.id_curriculo
    JOIN tb_disciplina d ON d.id_disciplina=cd.id_disciplina
    WHERE NOT EXISTS (SELECT 1 FROM aprovadas a WHERE a.id_disciplina=d.id_disciplina)
),
dependencias AS (
    SELECT c.id_disciplina AS origem,pr.id_requisito,
           ARRAY[c.id_disciplina,pr.id_requisito] AS caminho,
           pr.id_requisito=c.id_disciplina AS ciclo
    FROM candidatas c JOIN tb_pre_requisito pr ON pr.id_disciplina=c.id_disciplina
    WHERE pr.vinculo_pre_requisito='PRE_REQUISITO'
    UNION ALL
    SELECT dep.origem,pr.id_requisito,dep.caminho||pr.id_requisito,
           pr.id_requisito=ANY(dep.caminho)
    FROM dependencias dep
    JOIN tb_pre_requisito pr ON pr.id_disciplina=dep.id_requisito
    WHERE pr.vinculo_pre_requisito='PRE_REQUISITO' AND NOT dep.ciclo
)
SELECT c.codigo_disciplina,c.nome_disciplina,c.periodo_curriculo_disciplina,
       EXISTS (SELECT 1 FROM tb_pre_requisito pr
               WHERE pr.id_disciplina=c.id_disciplina
                 AND pr.vinculo_pre_requisito='CO_REQUISITO')
           AS exige_validar_co_requisito
FROM candidatas c CROSS JOIN parametros p
WHERE NOT EXISTS (
    SELECT 1 FROM dependencias dep
    WHERE dep.origem=c.id_disciplina
      AND (dep.ciclo OR NOT EXISTS (
          SELECT 1 FROM aprovadas a WHERE a.id_disciplina=dep.id_requisito
      ))
)
-- Exclui o que o aluno já tem matriculado no próprio semestre-alvo.
-- Não se olha a situacao do histórico: no início do semestre-alvo esse
-- resultado ainda não existe, e considerá-lo devolveria como "nova
-- elegibilidade" uma disciplina que o aluno já está cursando.
AND NOT EXISTS (
    SELECT 1 FROM tb_matricula m
    JOIN tb_turma t ON t.id_turma=m.id_turma
    WHERE m.id_aluno=p.id_aluno AND t.id_disciplina=c.id_disciplina
      AND t.id_periodo_letivo=p.id_periodo_letivo AND m.status_matricula='MATRICULADO'
)
ORDER BY c.periodo_curriculo_disciplina,c.codigo_disciplina;

-- 09. Ranking e percentil com funções de janela — requisito obrigatório.
-- Objetivo: comparar a média de cada aluno com as dos alunos do mesmo curso.
-- RANK: maior média recebe posição 1; empates compartilham posição.
-- PERCENT_RANK em ordem crescente: 0 = menor média; 100 = maior posição
-- relativa, com empates compartilhando o percentil inferior do grupo empatado.
-- Um grupo com apenas um aluno tem percentil 0 por definição da função.
-- Média aritmética das médias finais, não ponderada por carga horária.
WITH desempenho AS (
    SELECT c.id_curso,c.codigo_curso AS curso,a.id_aluno,
           a.matricula_aluno,a.nome_aluno,avg(h.media_final_historico) AS media
    FROM tb_aluno a JOIN tb_curso c ON c.id_curso=a.id_curso
    JOIN tb_matricula m ON m.id_aluno=a.id_aluno AND m.status_matricula='MATRICULADO'
    JOIN tb_historico h ON h.id_matricula=m.id_matricula
    WHERE h.media_final_historico IS NOT NULL AND h.situacao_historico<>'CURSANDO'
    GROUP BY c.id_curso,c.codigo_curso,a.id_aluno,a.matricula_aluno,a.nome_aluno
)
SELECT curso,matricula_aluno,nome_aluno,round(media,2) AS media,
       rank() OVER (PARTITION BY id_curso ORDER BY media DESC) AS posicao,
       round((100*percent_rank() OVER (
           PARTITION BY id_curso ORDER BY media
       ))::numeric,2) AS percentil
FROM desempenho ORDER BY curso,posicao,matricula_aluno;

-- 10. Evolução do rendimento com LAG — requisito obrigatório.
-- Objetivo: comparar a média semestral de cada aluno com a do período anterior.
-- Agrega por aluno/semestre ANTES de aplicar LAG: uma linha por período.
-- LAG preserva NULL no primeiro período, pois não há base de comparação.
-- Se houver lacunas no histórico, compara com o período anterior disponível.
WITH medias_semestrais AS (
    SELECT a.id_aluno,a.matricula_aluno,a.nome_aluno,
           p.ano_periodo_letivo,p.semestre_periodo_letivo,
           avg(h.media_final_historico) AS media
    FROM tb_aluno a JOIN tb_matricula m ON m.id_aluno=a.id_aluno
    JOIN tb_turma t ON t.id_turma=m.id_turma
    JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
    JOIN tb_historico h ON h.id_matricula=m.id_matricula
    WHERE m.status_matricula='MATRICULADO' AND h.media_final_historico IS NOT NULL
      AND h.situacao_historico<>'CURSANDO'
    GROUP BY a.id_aluno,a.matricula_aluno,a.nome_aluno,
             p.ano_periodo_letivo,p.semestre_periodo_letivo
), evolucao AS (
    SELECT *,lag(media) OVER (
        PARTITION BY id_aluno ORDER BY ano_periodo_letivo,semestre_periodo_letivo
    ) AS media_anterior
    FROM medias_semestrais
)
SELECT matricula_aluno,nome_aluno,ano_periodo_letivo,semestre_periodo_letivo,
       round(media,2) AS media_semestral,
       round(media_anterior,2) AS media_anterior,
       round(media-media_anterior,2) AS variacao
FROM evolucao ORDER BY matricula_aluno,ano_periodo_letivo,semestre_periodo_letivo;

COMMIT;
