# Roteiro de apresentação do Marco 2

Deixamos no [README](../README.md#baixar-e-preparar-na-sala) a montagem do banco e da conexão no pgAdmin. Para ensaiar com o cronômetro, usamos a divisão de tempo do [roteiro](../README.md#roteiro-para-o-dia).

1. Mostrar o schema e uma consulta ou view. Tentar gravar uma turma com zero vagas e explicar a restrição.
2. Executar um plano com EXPLAIN ANALYZE e comparar com as [evidências de antes e depois dos índices](INDICES.md).
3. Mostrar a superlotação sem proteção e as duas correções. Explicar a espera pelo bloqueio e a retentativa após o erro de serialização.
4. Rodar a mesma consulta de histórico com os logins de administrador e de aluno e comparar as contagens.
5. Restaurar o backup em um contêiner vazio e comparar as contagens pelo pgAdmin.

Antes da apresentação, precisamos confirmar com o professor o ambiente oficial, a escala e as responsabilidades. Na arguição individual, cada um de nós precisa explicar também a parte de outro colega.
