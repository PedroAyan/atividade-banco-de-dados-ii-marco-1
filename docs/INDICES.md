# Medição dos índices

Comparamos os planos com a mesma carga de 120 alunos, 10 turmas, 360 matrículas e 360 históricos. Rodamos cada consulta sete vezes antes e sete vezes depois de criar os índices, com cache aquecido e `ANALYZE` nas duas etapas. Deixamos o PostgreSQL escolher os planos normalmente, com `enable_seqscan` habilitado. Como os tempos são muito baixos, pequenas diferenças podem ser só ruído. Os planos completos estão em [indices.json](../evidencias/indices.json).

| Índice | Antes mediana ms | Depois mediana ms | Variação |
|---|---:|---:|---:|
| ix_matricula_ativa_turma | 0.028 | 0.029 | -3.6% |
| ix_turma_periodo | 0.009 | 0.008 | 11.1% |
| ix_aluno_curso | 0.018 | 0.017 | 5.6% |
| ix_historico_situacao | 0.028 | 0.012 | 57.1% |

O parcial atende contagem de vagas ativas; os demais filtram oferta por período, alunos por curso e resultados por situação. As tabelas pequenas e baixa seletividade podem favorecer varredura sequencial; ganho negativo significa regressão nesta amostra. Cada índice adiciona armazenamento e custo de escrita. O índice parcial de currículo do Marco 1 é preservado.

Reprodução: em cluster novo execute as etapas base, views e indices de `scripts/validar.py` conforme README. O JSON guarda as consultas, buffers e os sete planos antes/depois para cada índice.
