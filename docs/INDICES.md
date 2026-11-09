# Medição dos índices

Comparamos os planos com a mesma carga de 120 alunos, 10 turmas, 360 matrículas e 360 históricos. Rodamos cada consulta sete vezes antes e sete vezes depois de criar os índices, com cache aquecido e `ANALYZE` nas duas etapas. Deixamos o PostgreSQL escolher os planos normalmente, com `enable_seqscan` habilitado. Como os tempos são muito baixos, pequenas diferenças podem ser só ruído. Os planos completos estão em [indices.json](../evidencias/indices.json).

| Índice | Antes mediana ms | Depois mediana ms | Variação |
|---|---:|---:|---:|
| ix_matricula_ativa_turma | 0.028 | 0.029 | -3.6% |
| ix_turma_periodo | 0.009 | 0.008 | 11.1% |
| ix_aluno_curso | 0.018 | 0.017 | 5.6% |
| ix_historico_situacao | 0.028 | 0.012 | 57.1% |

Criamos o índice parcial para as consultas de vagas que contam só as matrículas ativas. Os outros ajudam a filtrar turmas por período, alunos por curso e históricos por situação. Na nossa amostra, a mediana da consulta de vagas subiu de 0,028 para 0,029 ms. Com tabelas pequenas ou filtros que trazem muitas linhas, a leitura sequencial pode custar menos. Cada índice ocupa espaço e precisa ser atualizado nas escritas. Mantivemos o índice parcial de currículo que já existia no Marco 1.

Para repetir o teste, use um cluster novo e rode as etapas `base`, `views` e `indices` de `scripts/validar.py` na ordem do README. Guardamos no JSON as consultas, os buffers e os sete planos de cada fase.
