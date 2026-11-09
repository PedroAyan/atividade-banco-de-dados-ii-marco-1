# Verificação técnica — 6 de novembro de 2026

Instalamos o projeto completo em um cluster novo de PostgreSQL 17.11, com DDL/carga/consultas e validação do Marco 1, três views, materialized view com refresh concorrente, quatro índices, funções de concorrência e segurança. Repetimos a instalação do zero com o código final e as verificações passaram. Nenhum volume ou banco anterior foi apagado; o Compose e SQL do Marco 1 permanecem intactos.

Guardamos em `indices.json` os planos das sete execuções de cada consulta antes e depois dos índices. Quando rodamos as duas conexões juntas, conseguimos colocar dois alunos numa turma com uma vaga. Com cada uma das correções, ficou só uma matrícula. No teste com `SERIALIZABLE`, vimos o erro `40001` e repetimos a transação. Depois, removemos as turmas artificiais dos bancos de teste.

Entramos com o login de um aluno e conseguimos ver os três históricos dele e nenhum de outro aluno. Tentamos mudar a identidade por uma variável de sessão e o filtro continuou o mesmo. Também tentamos inserir uma matrícula direto como secretaria e o banco barrou. A coordenação conseguiu atualizar uma nota, e depois desfizemos a alteração com rollback. Os resultados estão em `seguranca.json`.

Restauramos o backup binário em outro contêiner e comparamos as contagens e os hashes das 17 tabelas. Conferimos também índices, views, funções, políticas, permissões efetivas, concessões por coluna, vínculos entre papéis e sequências. O login restaurado continuou vendo apenas os próprios dados. Depois de corrigir a restauração das permissões dos construtores `RANGE`, repetimos o teste em um destino novo.

Limites: não houve validação no pacote Docker oficial nem pelo Query Tool do pgAdmin; falta confirmar a versão 16/17 contra o pacote real. Não houve benchmark de carga representativa, PITR/WAL ou desastre físico. Os integrantes e as responsabilidades registradas estão em [AUTORES.md](../AUTORES.md). A inspeção/exportação do diagrama no draw.io continua pendente conforme o guia original. O bônus opcional não foi implementado.

## Compatibilidade entre os marcos

Quando rodamos o script 99 depois de instalar o Marco 2, ele tratou a tabela `identidade_aluno` e sua chave estrangeira como objetos indevidos do Marco 1. Ajustamos a verificação para aceitar essa tabela adicional e continuar exigindo as 16 tabelas e 18 chaves estrangeiras originais. No banco com os dois marcos, passaram as dez consultas e os validadores 99 e 98. Também conferimos que a instalação só do Marco 1 passou e que o validador rejeitou uma tabela extra criada para o teste. Nos dois cenários de instalação, as contagens ficaram em 120 alunos, 10 turmas, 360 matrículas e 360 históricos. Registramos os detalhes em [compatibilidade-marcos.json](compatibilidade-marcos.json). O validador Python repete as consultas e o script 99 depois de instalar a segurança para cobrir esse caso.
