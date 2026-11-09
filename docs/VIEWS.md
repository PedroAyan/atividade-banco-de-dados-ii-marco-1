# Views e indicadores

Criamos três views para as consultas mais comuns. Em `v_oferta`, reunimos turma, disciplina e período. Em `v_vagas`, contamos apenas matrículas ativas e mostramos inclusive as turmas vazias. Já `v_historico` reúne o histórico e a identificação da matrícula e usa `security_invoker` para respeitar as regras de RLS de quem faz a consulta.

Na `mv_indicadores`, guardamos um resumo da oferta por período. Para os relatórios, aceitamos que o resumo fique até um dia atrasado. Ele já vem preenchido e pode ser atualizado depois do lote diário de matrículas e antes de apresentar relatórios.

O proprietário roda `REFRESH MATERIALIZED VIEW CONCURRENTLY academico.mv_indicadores;` fora de um bloco de transação. O índice único permite continuar consultando a view durante o refresh. Como cada atualização recalcula o resumo inteiro e usa I/O, evite agendar duas ao mesmo tempo e registre no agendador quando rodou e se terminou com sucesso. Na hora de decidir se ainda cabe alguém na turma, usamos os dados atuais das matrículas.
