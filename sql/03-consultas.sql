-- Marco 1 — 10 consultas de complexidade crescente.
-- PostgreSQL 17. Executar após 01-create-tables.sql e 02-insert-data.sql.
-- Somente leitura: não modifica os dados carregados.
BEGIN READ ONLY;
SET LOCAL search_path TO academico, public;

-- 01. Alunos ativos: projeção, filtro e ordenação.
-- Objetivo: listar os alunos ativos e sua data de ingresso.
SELECT matricula, nome, email, ingresso
FROM tb_aluno
WHERE ativo
ORDER BY matricula;

-- 02. Oferta de disciplinas: junções internas e junção opcional com professor.
-- Objetivo: listar as seis turmas de 2026/2 e seu responsável.
-- LEFT JOIN preserva turmas cujo id_professor seja NULL.
SELECT t.codigo AS turma, d.codigo AS disciplina, d.nome,
       p.ano, p.semestre, t.turno, pr.nome AS professor, t.vagas
FROM tb_turma t
JOIN tb_disciplina d ON d.id_disciplina=t.id_disciplina
JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
LEFT JOIN tb_professor pr ON pr.id_professor=t.id_professor
WHERE p.ano=2026 AND p.semestre=2
ORDER BY d.codigo,t.codigo;

-- 03. Histórico detalhado: junção de múltiplas tabelas.
-- Objetivo: consultar as notas e a situação do aluno de matrícula 20250001.
-- Use a matrícula pública, sem depender do valor gerado para tb_aluno.id_aluno.
SELECT a.matricula,a.nome,p.ano,p.semestre,d.codigo,d.nome AS disciplina,
       h.nota_a1,h.nota_a2,h.nota_p3,h.media_final,h.frequencia,h.situacao
FROM tb_aluno a
JOIN tb_matricula m ON m.id_aluno=a.id_aluno
JOIN tb_turma t ON t.id_turma=m.id_turma
JOIN tb_disciplina d ON d.id_disciplina=t.id_disciplina
JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
JOIN tb_historico h ON h.id_matricula=m.id_matricula
WHERE a.matricula='20250001'
ORDER BY p.ano,p.semestre,d.codigo;

-- 04. Junção externa com agregação — requisito obrigatório.
-- Objetivo: mostrar ocupação e vagas restantes, inclusive em turmas vazias.
-- COUNT(m.id_matricula), em vez de COUNT(*), não conta a linha artificial do LEFT JOIN.
-- O filtro de status fica no ON para preservar as turmas sem matrículas ativas.
SELECT p.ano,p.semestre,t.codigo,d.nome AS disciplina,t.vagas,
       count(m.id_matricula) AS ocupadas,t.vagas-count(m.id_matricula) AS restantes
FROM tb_turma t
JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
JOIN tb_disciplina d ON d.id_disciplina=t.id_disciplina
LEFT JOIN tb_matricula m ON m.id_turma=t.id_turma AND m.status='MATRICULADO'
GROUP BY p.ano,p.semestre,t.id_turma,t.codigo,d.nome,t.vagas
ORDER BY p.ano,p.semestre,t.codigo;

-- 05. Agregação com HAVING: cursos com pelo menos 30 alunos ativos.
-- Objetivo: filtrar grupos depois da contagem, em vez de filtrar linhas.
SELECT c.codigo,c.nome,count(a.id_aluno) AS alunos_ativos
FROM tb_curso c JOIN tb_aluno a ON a.id_curso=c.id_curso
WHERE a.ativo
GROUP BY c.id_curso,c.codigo,c.nome
HAVING count(a.id_aluno)>=30
ORDER BY alunos_ativos DESC,c.codigo;

-- 06. Subconsulta correlacionada com NOT EXISTS.
-- Objetivo: disciplinas do currículo do aluno ainda sem aprovação.
-- DISTINCT evita repetir uma disciplina cursada em várias turmas/períodos.
-- Esta consulta não avalia pré-requisitos; a consulta 08 faz essa verificação.
SELECT DISTINCT d.codigo,d.nome,cd.periodo,cd.tipo
FROM tb_aluno a
JOIN tb_curriculo_disciplina cd ON cd.id_curriculo=a.id_curriculo
JOIN tb_disciplina d ON d.id_disciplina=cd.id_disciplina
WHERE a.matricula='20250001'
  AND NOT EXISTS (
      SELECT 1 FROM tb_matricula m
      JOIN tb_turma t ON t.id_turma=m.id_turma
      JOIN tb_historico h ON h.id_matricula=m.id_matricula
      WHERE m.id_aluno=a.id_aluno AND t.id_disciplina=d.id_disciplina
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
    SELECT d.id_disciplina,d.codigo,d.nome,0 AS nivel,
           ARRAY[d.id_disciplina] AS visitados,d.codigo::text AS caminho
    FROM tb_disciplina d WHERE d.codigo='CCO072'
    UNION ALL
    SELECT r.id_disciplina,r.codigo,r.nome,c.nivel+1,
           c.visitados||r.id_disciplina,c.caminho||' -> '||r.codigo
    FROM cadeia c
    JOIN tb_pre_requisito pr ON pr.id_disciplina=c.id_disciplina
                            AND pr.vinculo='PRE_REQUISITO'
    JOIN tb_disciplina r ON r.id_disciplina=pr.id_requisito
    WHERE NOT r.id_disciplina=ANY(c.visitados)
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
    SELECT a.id_aluno,a.id_curriculo,p.id_periodo_letivo,p.data_inicio
    FROM tb_aluno a CROSS JOIN tb_periodo_letivo p
    WHERE a.matricula='20250001' AND p.ano=2026 AND p.semestre=2
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
    WHERE m.status='MATRICULADO' AND h.situacao='APROVADO'
      AND pl.data_fim<p.data_inicio
),
candidatas AS (
    SELECT d.id_disciplina,d.codigo,d.nome,cd.periodo
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
    WHERE pr.vinculo='PRE_REQUISITO'
    UNION ALL
    SELECT dep.origem,pr.id_requisito,dep.caminho||pr.id_requisito,
           pr.id_requisito=ANY(dep.caminho)
    FROM dependencias dep
    JOIN tb_pre_requisito pr ON pr.id_disciplina=dep.id_requisito
    WHERE pr.vinculo='PRE_REQUISITO' AND NOT dep.ciclo
)
SELECT c.codigo,c.nome,c.periodo,
       EXISTS (SELECT 1 FROM tb_pre_requisito pr
               WHERE pr.id_disciplina=c.id_disciplina AND pr.vinculo='CO_REQUISITO')
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
      AND t.id_periodo_letivo=p.id_periodo_letivo AND m.status='MATRICULADO'
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
    SELECT c.id_curso,c.codigo AS curso,a.id_aluno,
           a.matricula,a.nome,avg(h.media_final) AS media
    FROM tb_aluno a JOIN tb_curso c ON c.id_curso=a.id_curso
    JOIN tb_matricula m ON m.id_aluno=a.id_aluno AND m.status='MATRICULADO'
    JOIN tb_historico h ON h.id_matricula=m.id_matricula
    WHERE h.media_final IS NOT NULL AND h.situacao<>'CURSANDO'
    GROUP BY c.id_curso,c.codigo,a.id_aluno,a.matricula,a.nome
)
SELECT curso,matricula,nome,round(media,2) AS media,
       rank() OVER (PARTITION BY id_curso ORDER BY media DESC) AS posicao,
       round((100*percent_rank() OVER (
           PARTITION BY id_curso ORDER BY media
       ))::numeric,2) AS percentil
FROM desempenho ORDER BY curso,posicao,matricula;

-- 10. Evolução do rendimento com LAG — requisito obrigatório.
-- Objetivo: comparar a média semestral de cada aluno com a do período anterior.
-- Agrega por aluno/semestre ANTES de aplicar LAG: uma linha por período.
-- LAG preserva NULL no primeiro período, pois não há base de comparação.
-- Se houver lacunas no histórico, compara com o período anterior disponível.
WITH medias_semestrais AS (
    SELECT a.id_aluno,a.matricula,a.nome,p.ano,p.semestre,
           avg(h.media_final) AS media
    FROM tb_aluno a JOIN tb_matricula m ON m.id_aluno=a.id_aluno
    JOIN tb_turma t ON t.id_turma=m.id_turma
    JOIN tb_periodo_letivo p ON p.id_periodo_letivo=t.id_periodo_letivo
    JOIN tb_historico h ON h.id_matricula=m.id_matricula
    WHERE m.status='MATRICULADO' AND h.media_final IS NOT NULL
      AND h.situacao<>'CURSANDO'
    GROUP BY a.id_aluno,a.matricula,a.nome,p.ano,p.semestre
), evolucao AS (
    SELECT *,lag(media) OVER (
        PARTITION BY id_aluno ORDER BY ano,semestre
    ) AS media_anterior
    FROM medias_semestrais
)
SELECT matricula,nome,ano,semestre,round(media,2) AS media_semestral,
       round(media_anterior,2) AS media_anterior,
       round(media-media_anterior,2) AS variacao
FROM evolucao ORDER BY matricula,ano,semestre;

COMMIT;
