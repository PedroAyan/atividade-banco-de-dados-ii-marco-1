# Views e indicadores

Criamos três views para as consultas mais comuns. Em `v_oferta`, reunimos turma, disciplina e período. Em `v_vagas`, contamos apenas matrículas ativas e mostramos inclusive as turmas vazias. Já `v_historico` reúne o histórico e a identificação da matrícula e usa `security_invoker` para respeitar as regras de RLS de quem faz a consulta.

`mv_indicadores` consolida a oferta por período. Atualizar após o lote diário de matrículas e antes de apresentar relatórios: `REFRESH MATERIALIZED VIEW CONCURRENTLY academico.mv_indicadores;`. O índice único permite leitura durante a atualização. Executar fora de transação, como proprietário, sem agendar atualizações simultâneas. A visão é inicialmente populada; aceita defasagem de até um dia para relatórios. Para decidir matrícula, sempre usar dados transacionais atuais, nunca a materialized view. Atualizações custam recomputação integral e I/O; registrar horário e sucesso no agendador operacional.
