# Views e indicadores

`v_oferta` relaciona turma, disciplina e período; `v_vagas` conta somente matrículas ativas, incluindo turmas vazias; `v_historico` reúne histórico e identificação da matrícula, respeitando o RLS do usuário consultante (security_invoker).

`mv_indicadores` consolida a oferta por período. Atualizar após o lote diário de matrículas e antes de apresentar relatórios: `REFRESH MATERIALIZED VIEW CONCURRENTLY academico.mv_indicadores;`. O índice único permite leitura durante a atualização. Executar fora de transação, como proprietário, sem agendar atualizações simultâneas. A visão é inicialmente populada; aceita defasagem de até um dia para relatórios. Para decidir matrícula, sempre usar dados transacionais atuais, nunca a materialized view. Atualizações custam recomputação integral e I/O; registrar horário e sucesso no agendador operacional.
