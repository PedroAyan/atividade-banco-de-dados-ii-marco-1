# Disputa pela última vaga

A demonstração usa duas conexões reais sincronizadas por barreira em cluster isolado. Na versão ingênua, ambas contam zero matrículas e inserem: duas matrículas para uma vaga. `evidencias/concorrencia.json` registra a execução real.

`matricular_bloqueio` exige READ COMMITTED, bloqueia a linha da turma com FOR UPDATE e só então conta matrículas em outro comando, com snapshot atualizado. O segundo solicitante espera e recebe P0001 (turma lotada). O lock dura até COMMIT/ROLLBACK; manter a transação curta. Linhas de turmas diferentes não compartilham esse lock.

`matricular_serializavel` exige SERIALIZABLE. Ambos podem observar uma vaga; o PostgreSQL aborta um com SQLSTATE 40001. A aplicação precisa desfazer e repetir a transação inteira, inclusive consultas, com limite (por exemplo três tentativas) e atraso aleatório. A demonstração repete uma vez: encontra a turma lotada, P0001, e não insiste. 40P01 (deadlock) também exige rollback e retentativa limitada. 23505 significa matrícula duplicada e não deve virar nova matrícula. Outros erros devem ser reportados.

O bloqueio causa espera previsível por turma; SERIALIZABLE usa rastreamento de dependências e pode desperdiçar trabalho em rollback. Os tempos no JSON são de uma disputa didática, não um benchmark de carga. Ambas as correções deixam exatamente uma matrícula e criam seu histórico atomicamente. A anomalia e as turmas artificiais são removidas somente do banco temporário do teste; sequências podem avançar.

Produção: toda entrada de matrícula deve passar pela função, ou aderir ao mesmo protocolo. Os perfis do script 07 não têm INSERT direto nem permissão de reativar cancelamentos. O proprietário e superusuários são administradores de confiança e conseguem contornar essa proteção. Mudanças futuras de capacidade ou reativação precisam usar o mesmo bloqueio e validar lotação.

Exemplo secretaria: BEGIN ISOLATION LEVEL READ COMMITTED; SELECT academico.matricular_bloqueio(1,9); COMMIT;. Para a alternativa, BEGIN ISOLATION LEVEL SERIALIZABLE e matricular_serializavel. Ao receber qualquer erro execute ROLLBACK.

As estrategias sao alternativas: o perfil secretaria recebe somente a funcao de bloqueio. A demonstracao SERIALIZABLE roda como administrador isolado. Para adotar SERIALIZABLE operacionalmente, todos os escritores participantes precisam usar esse isolamento, revogando a rota READ COMMITTED. Nao misturar os dois protocolos.
