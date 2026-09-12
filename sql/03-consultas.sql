-- Marco 1 — 10 consultas de complexidade crescente.
-- PostgreSQL 17. Executar após 01-create-tables.sql e 02-insert-data.sql.
-- Somente leitura: não modifica os dados carregados.
BEGIN READ ONLY;
SET LOCAL search_path TO academico, public;

-- 01. Alunos ativos: projeção, filtro e ordenação.
-- Objetivo: listar os alunos ativos e sua data de ingresso.
SELECT matricula, nome, email, ingresso
FROM aluno
WHERE ativo
ORDER BY matricula;

-- 02. Oferta de disciplinas: junções internas e junção opcional com professor.
-- Objetivo: listar as seis turmas de 2026/2 e seu responsável.
-- LEFT JOIN preserva turmas cujo professor_id seja NULL.
SELECT t.codigo AS turma, d.codigo AS disciplina, d.nome,
       p.ano, p.semestre, t.turno, pr.nome AS professor, t.vagas
FROM turma t
JOIN disciplina d ON d.id=t.disciplina_id
JOIN periodo_letivo p ON p.id=t.periodo_letivo_id
LEFT JOIN professor pr ON pr.id=t.professor_id
WHERE p.ano=2026 AND p.semestre=2
ORDER BY d.codigo,t.codigo;

-- 03. Histórico detalhado: junção de múltiplas tabelas.
-- Objetivo: consultar as notas e a situação do aluno de matrícula 20250001.
-- Use a matrícula pública, sem depender do valor gerado para aluno.id.
SELECT a.matricula,a.nome,p.ano,p.semestre,d.codigo,d.nome AS disciplina,
       h.nota_a1,h.nota_a2,h.nota_p3,h.media_final,h.frequencia,h.situacao
FROM aluno a
JOIN matricula m ON m.aluno_id=a.id
JOIN turma t ON t.id=m.turma_id
JOIN disciplina d ON d.id=t.disciplina_id
JOIN periodo_letivo p ON p.id=t.periodo_letivo_id
JOIN historico h ON h.matricula_id=m.id
WHERE a.matricula='20250001'
ORDER BY p.ano,p.semestre,d.codigo;

-- 04. Junção externa com agregação — requisito obrigatório.
-- Objetivo: mostrar ocupação e vagas restantes, inclusive em turmas vazias.
-- COUNT(m.id), em vez de COUNT(*), não conta a linha artificial do LEFT JOIN.
-- O filtro de status fica no ON para preservar as turmas sem matrículas ativas.
SELECT p.ano,p.semestre,t.codigo,d.nome AS disciplina,t.vagas,
       count(m.id) AS ocupadas,t.vagas-count(m.id) AS restantes
FROM turma t
JOIN periodo_letivo p ON p.id=t.periodo_letivo_id
JOIN disciplina d ON d.id=t.disciplina_id
LEFT JOIN matricula m ON m.turma_id=t.id AND m.status='MATRICULADO'
GROUP BY p.ano,p.semestre,t.id,t.codigo,d.nome,t.vagas
ORDER BY p.ano,p.semestre,t.codigo;

-- 05. Agregação com HAVING: cursos com pelo menos 30 alunos ativos.
-- Objetivo: filtrar grupos depois da contagem, em vez de filtrar linhas.
SELECT c.codigo,c.nome,count(a.id) AS alunos_ativos
FROM curso c JOIN aluno a ON a.curso_id=c.id
WHERE a.ativo
GROUP BY c.id,c.codigo,c.nome
HAVING count(a.id)>=30
ORDER BY alunos_ativos DESC,c.codigo;

-- 06. Subconsulta correlacionada com NOT EXISTS.
-- Objetivo: disciplinas do currículo do aluno ainda sem aprovação.
-- DISTINCT evita repetir uma disciplina cursada em várias turmas/períodos.
-- Esta consulta não avalia pré-requisitos; a consulta 08 faz essa verificação.
SELECT DISTINCT d.codigo,d.nome,cd.periodo,cd.tipo
FROM aluno a
JOIN curriculo_disciplina cd ON cd.curriculo_id=a.curriculo_id
JOIN disciplina d ON d.id=cd.disciplina_id
WHERE a.matricula='20250001'
  AND NOT EXISTS (
      SELECT 1 FROM matricula m
      JOIN turma t ON t.id=m.turma_id
      JOIN historico h ON h.matricula_id=m.id
      WHERE m.aluno_id=a.id AND t.disciplina_id=d.id
        AND m.status='MATRICULADO' AND h.situacao='APROVADO'
  )
ORDER BY cd.periodo,d.codigo;

-- 07. Árvore recursiva de pré-requisitos — requisito obrigatório.
-- Objetivo: mostrar a cadeia de dependências de Banco de Dados II (CCO072).
-- Âncora: a própria disciplina, nível zero. Passo: seguir cada pré-requisito.
-- O array visitados impede revisitar um vértice no mesmo caminho: a consulta
-- termina mesmo se houver um ciclo indireto. Não há corte arbitrário de nível.
-- Filtra PRE_REQUISITO: co-requisitos não são exigências de aprovação anterior.
WITH RECURSIVE cadeia AS (
    SELECT d.id,d.codigo,d.nome,0 AS nivel,
           ARRAY[d.id] AS visitados,d.codigo::text AS caminho
    FROM disciplina d WHERE d.codigo='CCO072'
    UNION ALL
    SELECT r.id,r.codigo,r.nome,c.nivel+1,
           c.visitados||r.id,c.caminho||' -> '||r.codigo
    FROM cadeia c
    JOIN pre_requisito pr ON pr.disciplina_id=c.id
                            AND pr.vinculo='PRE_REQUISITO'
    JOIN disciplina r ON r.id=pr.requisito_id
    WHERE NOT r.id=ANY(c.visitados)
)
SELECT nivel,codigo,nome,caminho
FROM cadeia ORDER BY caminho;

-- 08. Disciplinas que um aluno já pode cursar — requisito recursivo obrigatório.
-- Recorte temporal: a consulta responde o que o aluno pode cursar NO INÍCIO do
-- semestre-alvo. Todo o julgamento usa apenas fatos anteriores a esse início.
-- Critério: pertence ao currículo, ainda não foi aprovada em período anterior e
-- TODOS os pré-requisitos diretos e indiretos foram aprovados em período
-- letivo estritamente anterior ao alvo (pl.data_fim < data_inicio do alvo).
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
    SELECT a.id AS aluno_id,a.curriculo_id,p.id AS periodo_id,p.data_inicio
    FROM aluno a CROSS JOIN periodo_letivo p
    WHERE a.matricula='20250001' AND p.ano=2026 AND p.semestre=2
),
-- Aprovações válidas como pré-requisito: só períodos encerrados ANTES do
-- início do semestre-alvo. O próprio semestre-alvo nunca entra aqui.
aprovadas AS (
    SELECT DISTINCT t.disciplina_id
    FROM parametros p
    JOIN matricula m ON m.aluno_id=p.aluno_id
    JOIN turma t ON t.id=m.turma_id
    JOIN periodo_letivo pl ON pl.id=t.periodo_letivo_id
    JOIN historico h ON h.matricula_id=m.id
    WHERE m.status='MATRICULADO' AND h.situacao='APROVADO'
      AND pl.data_fim<p.data_inicio
),
candidatas AS (
    SELECT d.id,d.codigo,d.nome,cd.periodo
    FROM parametros p
    JOIN curriculo_disciplina cd ON cd.curriculo_id=p.curriculo_id
    JOIN disciplina d ON d.id=cd.disciplina_id
    WHERE NOT EXISTS (SELECT 1 FROM aprovadas a WHERE a.disciplina_id=d.id)
),
dependencias AS (
    SELECT c.id AS origem,pr.requisito_id,
           ARRAY[c.id,pr.requisito_id] AS caminho,
           pr.requisito_id=c.id AS ciclo
    FROM candidatas c JOIN pre_requisito pr ON pr.disciplina_id=c.id
    WHERE pr.vinculo='PRE_REQUISITO'
    UNION ALL
    SELECT dep.origem,pr.requisito_id,dep.caminho||pr.requisito_id,
           pr.requisito_id=ANY(dep.caminho)
    FROM dependencias dep
    JOIN pre_requisito pr ON pr.disciplina_id=dep.requisito_id
    WHERE pr.vinculo='PRE_REQUISITO' AND NOT dep.ciclo
)
SELECT c.codigo,c.nome,c.periodo,
       EXISTS (SELECT 1 FROM pre_requisito pr
               WHERE pr.disciplina_id=c.id AND pr.vinculo='CO_REQUISITO')
           AS exige_validar_co_requisito
FROM candidatas c CROSS JOIN parametros p
WHERE NOT EXISTS (
    SELECT 1 FROM dependencias dep
    WHERE dep.origem=c.id
      AND (dep.ciclo OR NOT EXISTS (
          SELECT 1 FROM aprovadas a WHERE a.disciplina_id=dep.requisito_id
      ))
)
-- Exclui o que o aluno já tem matriculado no próprio semestre-alvo.
-- Não se olha a situacao do histórico: no início do semestre-alvo esse
-- resultado ainda não existe, e considerá-lo devolveria como "nova
-- elegibilidade" uma disciplina que o aluno já está cursando.
AND NOT EXISTS (
    SELECT 1 FROM matricula m
    JOIN turma t ON t.id=m.turma_id
    WHERE m.aluno_id=p.aluno_id AND t.disciplina_id=c.id
      AND t.periodo_letivo_id=p.periodo_id AND m.status='MATRICULADO'
)
ORDER BY c.periodo,c.codigo;

-- 09. Ranking e percentil com funções de janela — requisito obrigatório.
-- Objetivo: comparar a média de cada aluno com as dos alunos do mesmo curso.
-- RANK: maior média recebe posição 1; empates compartilham posição.
-- PERCENT_RANK em ordem crescente: 0 = menor média; 100 = maior posição
-- relativa, com empates compartilhando o percentil inferior do grupo empatado.
-- Um grupo com apenas um aluno tem percentil 0 por definição da função.
-- Média aritmética das médias finais, não ponderada por carga horária.
WITH desempenho AS (
    SELECT c.id AS curso_id,c.codigo AS curso,a.id AS aluno_id,
           a.matricula,a.nome,avg(h.media_final) AS media
    FROM aluno a JOIN curso c ON c.id=a.curso_id
    JOIN matricula m ON m.aluno_id=a.id AND m.status='MATRICULADO'
    JOIN historico h ON h.matricula_id=m.id
    WHERE h.media_final IS NOT NULL AND h.situacao<>'CURSANDO'
    GROUP BY c.id,c.codigo,a.id,a.matricula,a.nome
)
SELECT curso,matricula,nome,round(media,2) AS media,
       rank() OVER (PARTITION BY curso_id ORDER BY media DESC) AS posicao,
       round((100*percent_rank() OVER (
           PARTITION BY curso_id ORDER BY media
       ))::numeric,2) AS percentil
FROM desempenho ORDER BY curso,posicao,matricula;

-- 10. Evolução do rendimento com LAG — requisito obrigatório.
-- Objetivo: comparar a média semestral de cada aluno com a do período anterior.
-- Agrega por aluno/semestre ANTES de aplicar LAG: uma linha por período.
-- LAG preserva NULL no primeiro período, pois não há base de comparação.
-- Se houver lacunas no histórico, compara com o período anterior disponível.
WITH medias_semestrais AS (
    SELECT a.id AS aluno_id,a.matricula,a.nome,p.ano,p.semestre,
           avg(h.media_final) AS media
    FROM aluno a JOIN matricula m ON m.aluno_id=a.id
    JOIN turma t ON t.id=m.turma_id
    JOIN periodo_letivo p ON p.id=t.periodo_letivo_id
    JOIN historico h ON h.matricula_id=m.id
    WHERE m.status='MATRICULADO' AND h.media_final IS NOT NULL
      AND h.situacao<>'CURSANDO'
    GROUP BY a.id,a.matricula,a.nome,p.ano,p.semestre
), evolucao AS (
    SELECT *,lag(media) OVER (
        PARTITION BY aluno_id ORDER BY ano,semestre
    ) AS media_anterior
    FROM medias_semestrais
)
SELECT matricula,nome,ano,semestre,round(media,2) AS media_semestral,
       round(media_anterior,2) AS media_anterior,
       round(media-media_anterior,2) AS variacao
FROM evolucao ORDER BY matricula,ano,semestre;

COMMIT;
