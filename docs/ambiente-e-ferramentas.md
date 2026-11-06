# Ambiente e ferramentas do projeto

Este documento registra as ferramentas e o ambiente exigidos pelo professor para
o projeto acadêmico de Banco de Dados II. As exigências abaixo vêm do comunicado
do professor sobre o projeto acadêmico e o ambiente da disciplina. Este documento
não substitui o guia de instalação oficial.

## Ferramentas obrigatórias

| Finalidade | Ferramenta exigida |
|---|---|
| Modelagem do banco de dados | **draw.io**, exclusivamente |
| Administração do banco e execução de SQL | **pgAdmin 4**, exclusivamente |
| Banco de dados | **A confirmar no pacote oficial** (registros locais divergem entre 16 e 17), em Docker |
| Ambiente | **Docker** e o pacote Docker fornecido pela disciplina |

Regras que decorrem do comunicado:

- **Modelagem:** toda a modelagem é feita no draw.io. Nenhuma outra ferramenta de
  modelagem ou de geração de diagramas é usada.
- **Administração:** o DBeaver foi descontinuado na disciplina. Não se usa DBeaver
  nem outro cliente ou interface gráfica de banco como substituto do pgAdmin 4.
- **Banco:** usa-se o banco já fornecido no pacote Docker da disciplina. Não se
  cria um banco separado nem se usa outra versão do PostgreSQL na validação
  oficial.

## Preparação do ambiente

O pacote Docker e o guia de instalação são distribuídos pelo **Google Classroom**
da disciplina. O pacote já inclui o banco de dados usado no curso.

Este repositório **não** reproduz o conteúdo desse pacote nem do guia. Portanto,
as credenciais, a porta, o nome do banco e os comandos de inicialização **não
estão documentados aqui** e devem ser obtidos no guia oficial. Siga o guia do
professor para iniciar o ambiente e confirmar a versão real com `SHOW server_version` e a imagem Compose do pacote.

Não crie um banco de dados à parte e não altere a configuração Docker fornecida.
Não apague volumes do Docker nem os dados do banco do curso.

> O arquivo `docker-compose.yml` deste repositório é a configuração usada nos
> testes da própria equipe (imagem `postgres:17`). **Não é o pacote oficial** da
> disciplina; compatibilidade técnica não comprova conformidade oficial.

## Execução dos scripts SQL (pgAdmin 4)

1. Inicie o ambiente do curso conforme o guia oficial.
2. Abra o pgAdmin 4 e conecte-o ao banco **já existente** do pacote da disciplina,
   com os dados de conexão do guia oficial.
3. Antes de executar qualquer script, inspecione o banco e o schema de destino:
   verifique se já existe o schema `academico`, se existem tabelas `tb_*` e se há
   dados.
4. Se houver objetos em conflito ou dados do projeto já carregados, **interrompa**
   e comunique o professor ou a equipe. Os scripts não devem ser usados para
   apagar, recriar ou sobrescrever nada.
5. Abra o **Query Tool** do pgAdmin 4 e execute, nesta ordem:
   1. `sql/01-create-tables.sql`
   2. `sql/02-insert-data.sql`
   3. `sql/03-consultas.sql`
   4. `sql/99-validacao.sql`

Precauções:

- `01-create-tables.sql` cria o schema `academico` e falha se ele já existir;
  executa-se uma única vez, em banco novo. Também executa
  `CREATE EXTENSION IF NOT EXISTS btree_gist`, que exige permissão para instalar
  extensões.
- `02-insert-data.sql` recusa a carga se alguma tabela já tiver registros.
- `03-consultas.sql` e `99-validacao.sql` são somente leitura.
- `99-validacao.sql` confere 16 tabelas com prefixo `tb_`, as chaves primárias, os
  18 relacionamentos (chaves estrangeiras), as colunas geradas e a carga
  esperada.

## Convenções de nomes

- Tabelas: `tb_<tabela>`.
- Identificadores (PK e FK): `id_<entidade>`. Em `tb_pre_requisito`, a segunda
  referência a disciplina chama-se `id_requisito`.
- Demais atributos: `<atributo>_<entidade>`, por exemplo `nome_curso` e
  `matricula_aluno`. `tb_matricula.data_matricula` já segue o padrão.

## Diagrama (draw.io)

O arquivo `diagramabancodedadosii.drawio` é a **fonte editável** do diagrama. O
PDF `diagramabancodedadosii.drawio.pdf` é apenas a sua exportação.

1. Abra `diagramabancodedadosii.drawio` no draw.io.
2. Edite tabelas, colunas e relacionamentos dentro do próprio draw.io,
   preservando as convenções de nomes acima.
3. Confira visualmente as 16 tabelas, seus atributos, os 18 conectores e as
   cardinalidades (1, 0..1 e 0..N), além da legenda.
4. Exporte o PDF diretamente do draw.io (Arquivo → Exportar como → PDF) e
   substitua `diagramabancodedadosii.drawio.pdf`.

## Situação atual e pendências

- Os scripts SQL já usam as convenções acima. Os testes feitos até aqui rodaram em
  PostgreSQL 17, em contêiner temporário e com o cliente `psql`. Isso é apenas
  histórico de testes e **não** substitui a validação oficial.
- A validação oficial — versão a confirmar no pacote da disciplina, pgAdmin 4 e Query
  Tool — **ainda não foi realizada**.
- O arquivo `diagramabancodedadosii.drawio` foi gerado e atualizado por script, e
  não dentro do draw.io. Deve ser aberto no draw.io, inspecionado visualmente e
  salvo por lá.
- O PDF do diagrama está **desatualizado** (nomes e rótulos antigos) e precisa ser
  exportado do draw.io.
- Dependência: o pacote Docker e o guia oficial do Google Classroom.

## Confirmação pendente da versão (Marco 2)

O enunciado local indica PostgreSQL 17; a anotação anterior deste guia dizia 16. Não foi localizado o pacote Docker efetivamente fornecido pela disciplina nos arquivos disponíveis. Nenhuma dessas anotações substitui esse pacote. Os testes novos foram feitos em PostgreSQL 17.11 isolado e não são validação oficial. Para encerrar a divergência, registrar a tag/digest da imagem oficial, `SHOW server_version`, data e origem do pacote, e repetir a demonstração no pgAdmin. A ordem atualizada dos SQL 04–07 e 98 está no README.
