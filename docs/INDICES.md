# Medição dos índices

PostgreSQL e planos completos em `evidencias/indices.json`. Carga original inalterada: 120 alunos, 10 turmas e 360 históricos/matrículas. Sete execuções por consulta, mesmas condições e ANALYZE em ambas as fases; cache aquecido. Não usamos enable_seqscan=off. Tempos pequenos têm ruído e não sustentam promessa de aceleração.

| Índice | Antes mediana ms | Depois mediana ms | Variação |
|---|---:|---:|---:|
| ix_matricula_ativa_turma | 0.027 | 0.027 | 0.0% |
| ix_turma_periodo | 0.010 | 0.008 | 20.0% |
| ix_aluno_curso | 0.018 | 0.017 | 5.6% |
| ix_historico_situacao | 0.026 | 0.010 | 61.5% |

O parcial atende contagem de vagas ativas; os demais filtram oferta por período, alunos por curso e resultados por situação. As tabelas pequenas e baixa seletividade podem favorecer varredura sequencial; ganho negativo significa regressão nesta amostra. Cada índice adiciona armazenamento e custo de escrita. O índice parcial de currículo do Marco 1 é preservado.

Reprodução: em cluster novo execute as etapas base, views e indices de `scripts/validar.py` conforme README. O JSON guarda as consultas, buffers e os sete planos antes/depois para cada índice.
