# Roteiro de apresentação do Marco 2

O [README](../README.md#baixar-e-preparar-na-sala) reúne os comandos para preparar o PostgreSQL, conectar ao pgAdmin e ensaiar do zero. O [roteiro para o dia](../README.md#roteiro-para-o-dia) distribui a demonstração em cerca de nove minutos.

1. Mostrar o schema e uma consulta ou view. Tentar gravar uma turma com zero vagas e explicar a restrição.
2. Executar um plano com EXPLAIN ANALYZE e comparar com as [evidências de antes e depois dos índices](INDICES.md).
3. Mostrar a superlotação sem proteção e as duas correções. Explicar a espera pelo bloqueio e a retentativa após o erro de serialização.
4. Rodar a mesma consulta de histórico com os logins de administrador e de aluno e comparar as contagens.
5. Restaurar o backup em um contêiner vazio e comparar as contagens pelo pgAdmin.

Confirmem o ambiente oficial, a escala e as responsabilidades do grupo com o professor. Na arguição individual, cada integrante responde sobre a frente de outro colega.
