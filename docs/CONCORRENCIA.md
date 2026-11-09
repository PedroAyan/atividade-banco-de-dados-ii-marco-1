# Disputa pela última vaga

Para reproduzir a disputa pela última vaga, abrimos duas conexões no mesmo banco de teste e sincronizamos as tentativas com uma barreira. Sem proteção, as duas sessões veem a vaga livre e matriculam alunos diferentes. A turma acaba com duas matrículas para uma vaga. Registramos a execução em [concorrencia.json](../evidencias/concorrencia.json).

Na primeira solução, `matricular_bloqueio` usa `READ COMMITTED`. A função trava a linha da turma com `FOR UPDATE` e só depois conta as matrículas em outro comando, que já enxerga as mudanças confirmadas. O segundo pedido espera e, no nosso teste, recebeu `P0001` porque a turma lotou. O bloqueio dura até `COMMIT` ou `ROLLBACK`, então vale manter a transação curta. Pedidos de turmas diferentes travam linhas diferentes.

`matricular_serializavel` exige SERIALIZABLE. Ambos podem observar uma vaga; o PostgreSQL aborta um com SQLSTATE 40001. A aplicação precisa desfazer e repetir a transação inteira, inclusive consultas, com limite (por exemplo três tentativas) e atraso aleatório. A demonstração repete uma vez: encontra a turma lotada, P0001, e não insiste. 40P01 (deadlock) também exige rollback e retentativa limitada. 23505 significa matrícula duplicada e não deve virar nova matrícula. Outros erros devem ser reportados.

Com bloqueio, um pedido espera pelo outro na mesma turma. Com `SERIALIZABLE`, o PostgreSQL acompanha as dependências entre transações e pode mandar refazer um pedido que já tinha começado. Nos dois testes, sobrou uma matrícula e o histórico dela foi criado na mesma transação. Os tempos no JSON são desse ensaio com duas conexões. Removemos as turmas artificiais só do banco de teste. As sequências podem avançar mesmo assim.

Produção: toda entrada de matrícula deve passar pela função, ou aderir ao mesmo protocolo. Os perfis do script 07 não têm INSERT direto nem permissão de reativar cancelamentos. O proprietário e superusuários são administradores de confiança e conseguem contornar essa proteção. Mudanças futuras de capacidade ou reativação precisam usar o mesmo bloqueio e validar lotação.

Exemplo secretaria: BEGIN ISOLATION LEVEL READ COMMITTED; SELECT academico.matricular_bloqueio(1,9); COMMIT;. Para a alternativa, BEGIN ISOLATION LEVEL SERIALIZABLE e matricular_serializavel. Ao receber qualquer erro execute ROLLBACK.

No projeto, liberamos para a secretaria apenas a função que usa bloqueio. Para comparar as duas estratégias, demonstramos `SERIALIZABLE` como administrador em um banco isolado. Se adotarmos essa estratégia no sistema, todas as operações que gravam matrículas terão de usar o mesmo isolamento e a rota com `READ COMMITTED` terá de ser revogada.
