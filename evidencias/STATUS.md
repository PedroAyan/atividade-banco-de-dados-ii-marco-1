# Verificação técnica — 6 de novembro de 2026

Instalação completa executada em cluster novo PostgreSQL 17.11, incluindo DDL/carga/consultas e validação do Marco 1, três views, materialized view com refresh concorrente, quatro índices, funções de concorrência e segurança. Uma segunda instalação limpa passou com o código final. Nenhum volume ou banco anterior foi apagado; o Compose e SQL do Marco 1 permanecem intactos.

Os planos de sete execuções antes/depois de cada índice estão em indices.json. A demonstração sincronizada de duas conexões reproduziu superlotação 2/1; ambas as correções deixaram 1/1, com 40001 e retentativa no cenário SERIALIZABLE. As turmas artificiais foram removidas apenas dos clusters de teste.

Login real sem privilégios administrativos leu três históricos próprios e zero de outro aluno. Alterar variável de sessão não mudou a identidade. Escrita direta da secretaria foi negada e atualização de nota pela coordenação foi executada com rollback. Ver seguranca.json.

Backup binário foi restaurado do zero em outro contêiner, comparando hashes e contagens de 17 tabelas. Índices, views, funções, políticas, ACLs efetivas, concessões de colunas, memberships e sequências coincidiram. O login restaurado manteve o RLS. O procedimento final foi repetido em novo destino após corrigir a recuperação das ACLs dos construtores RANGE.

Limites: não houve validação no pacote Docker oficial nem pelo Query Tool do pgAdmin; falta confirmar a versão 16/17 contra o pacote real. Não houve benchmark de carga representativa, PITR/WAL ou desastre físico. Composição do grupo e responsabilidades formais adicionais dependem do professor; AUTORES.md foi preservado. A inspeção/exportação do diagrama no draw.io continua pendente conforme o guia original. O bônus opcional não foi implementado.

## Compatibilidade entre os marcos

A reexecucao do validador 99 apos o Marco 2 identificou uma incompatibilidade na propria verificacao: a tabela adicional identidade_aluno e sua FK eram contadas como objetos indevidos do Marco 1. O validador foi ajustado para permitir somente essa tabela adicional e manter obrigatorias as 16 tabelas e 18 FKs originais. As dez consultas e os validadores 99/98 passaram no banco integrado; uma instalacao nova somente do Marco 1 tambem passou. Uma tabela desconhecida artificial foi corretamente rejeitada. Contagens permaneceram 120/10/360/360 em ambos os cenarios; detalhes em compatibilidade-marcos.json. O validador Python agora repete as consultas e o script 99 depois de instalar a seguranca, para cobrir essa regressao.
