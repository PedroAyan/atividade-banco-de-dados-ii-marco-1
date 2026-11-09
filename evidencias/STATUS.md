# Verificação técnica — 6 de novembro de 2026

Instalamos o projeto completo em um cluster novo de PostgreSQL 17.11, com DDL/carga/consultas e validação do Marco 1, três views, materialized view com refresh concorrente, quatro índices, funções de concorrência e segurança. Repetimos a instalação do zero com o código final e as verificações passaram. Nenhum volume ou banco anterior foi apagado; o Compose e SQL do Marco 1 permanecem intactos.

Os planos de sete execuções antes/depois de cada índice estão em indices.json. A demonstração sincronizada de duas conexões reproduziu superlotação 2/1; ambas as correções deixaram 1/1, com 40001 e retentativa no cenário SERIALIZABLE. As turmas artificiais foram removidas apenas dos clusters de teste.

Login real sem privilégios administrativos leu três históricos próprios e zero de outro aluno. Alterar variável de sessão não mudou a identidade. Escrita direta da secretaria foi negada e atualização de nota pela coordenação foi executada com rollback. Ver seguranca.json.

Backup binário foi restaurado do zero em outro contêiner, comparando hashes e contagens de 17 tabelas. Índices, views, funções, políticas, ACLs efetivas, concessões de colunas, memberships e sequências coincidiram. O login restaurado manteve o RLS. O procedimento final foi repetido em novo destino após corrigir a recuperação das ACLs dos construtores RANGE.

Limites: não houve validação no pacote Docker oficial nem pelo Query Tool do pgAdmin; falta confirmar a versão 16/17 contra o pacote real. Não houve benchmark de carga representativa, PITR/WAL ou desastre físico. Os integrantes e as responsabilidades registradas estão em [AUTORES.md](../AUTORES.md). A inspeção/exportação do diagrama no draw.io continua pendente conforme o guia original. O bônus opcional não foi implementado.

## Compatibilidade entre os marcos

Quando rodamos o script 99 depois de instalar o Marco 2, ele tratou a tabela `identidade_aluno` e sua chave estrangeira como objetos indevidos do Marco 1. Ajustamos a verificação para aceitar essa tabela adicional e continuar exigindo as 16 tabelas e 18 chaves estrangeiras originais. No banco com os dois marcos, passaram as dez consultas e os validadores 99 e 98. Também conferimos que a instalação só do Marco 1 passou e que o validador rejeitou uma tabela extra criada para o teste. Nos dois cenários de instalação, as contagens ficaram em 120 alunos, 10 turmas, 360 matrículas e 360 históricos. Registramos os detalhes em [compatibilidade-marcos.json](compatibilidade-marcos.json). O validador Python repete as consultas e o script 99 depois de instalar a segurança para cobrir esse caso.
