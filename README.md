# Sistema de Matrícula Acadêmica — Marco 1

## Descrição

Projeto desenvolvido para a disciplina de Banco de Dados II.

O projeto consiste no desenvolvimento de um banco de dados para um Sistema de
Matrícula Acadêmica, contemplando o gerenciamento de campi, cursos, currículos,
disciplinas, pré-requisitos, professores, salas, períodos letivos, turmas,
alunos, matrículas e histórico escolar.

## Escopo do Marco 1

- DDL completo: schema `academico`, tipos, domínios, 16 tabelas e restrições de
  integridade declarativas (PK, FK, UNIQUE, CHECK, EXCLUDE e índice parcial).
- Carga didática determinística: 120 alunos, 10 turmas (6 na oferta de 2026/2),
  360 matrículas e 360 registros de histórico.
- 10 consultas comentadas, de complexidade crescente, incluindo junção externa
  com agregação, duas consultas recursivas e duas com funções de janela.

Este marco não implementa transações concorrentes, views, segurança, auditoria
automática por gatilho nem controle de disputa pela última vaga.

## Requisitos

- Docker
- Docker Compose
- PostgreSQL 17 — fornecido pelo contêiner, não é necessário instalar localmente

## Estrutura do repositório

```
README.md
AUTORES.md
diagramabancodedadosii.drawio.pdf
docker-compose.yml
sql/
  01-create-tables.sql
  02-insert-data.sql
  03-consultas.sql
  99-validacao.sql
```

## Execução

Todos os comandos abaixo são executados **na raiz do repositório**, logo após o
clone. Os exemplos usam Git Bash no Windows, e funcionam igualmente em Linux e
macOS.

1. Clonar o repositório e entrar na pasta:

```bash
git clone https://github.com/PedroAyan/atividade-banco-de-dados-ii-marco-1.git
cd atividade-banco-de-dados-ii-marco-1
```

2. Iniciar o ambiente e esperar o banco ficar realmente pronto:

```bash
docker compose up -d --wait
```

O `--wait` só devolve o controle quando o healthcheck do serviço confirma que o
PostgreSQL **definitivo** está aceitando conexões. Na primeira execução, com o
volume vazio, isso demora alguns segundos a mais, porque o contêiner ainda
precisa inicializar o banco antes de liberar o servidor final.

3. Conferir que o serviço está saudável:

```bash
docker compose ps
```

A coluna `STATUS` deve mostrar `Up ... (healthy)`.

4. Criar o schema e as tabelas (**uma única vez, em um banco novo**):

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d matricula_academica < sql/01-create-tables.sql
```

5. Carregar os dados:

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d matricula_academica < sql/02-insert-data.sql
```

Ao final, o script imprime as quantidades carregadas: 120 alunos, 10 turmas,
360 matrículas e 360 históricos.

6. Executar as 10 consultas:

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d matricula_academica < sql/03-consultas.sql
```

7. Listar as tabelas criadas:

```bash
docker compose exec -T postgres psql -X -U postgres -d matricula_academica -c '\dt academico.*'
```

O resultado esperado é uma lista com as 16 tabelas do modelo.

### Conferir a entrega (opcional)

O arquivo `sql/99-validacao.sql` **não faz parte da criação do banco**: a ordem
normal continua sendo 01, 02 e 03. Ele existe para conferir, depois que 01 e 02
rodaram, se a entrega do Marco 1 está íntegra.

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d matricula_academica < sql/99-validacao.sql
```

São verificações **somente leitura** (a transação é `READ ONLY`), então o script
não altera nenhum dado e pode ser executado quantas vezes quiser. Ele confere o
schema, as 16 tabelas pelo nome, as chaves primárias, os 18 relacionamentos do
modelo um a um, a ausência de FK em `log_matricula`, as colunas geradas, os
mínimos exigidos pelo enunciado (100 alunos, 6 turmas, 300 matrículas) e a
existência de turma sem matrícula para a consulta 04.

Em caso de sucesso, termina com um resumo. Havendo qualquer inconsistência, ele
encerra com erro e lista todos os problemas encontrados de uma vez.

### Recomeçar do zero

Os scripts não apagam dados: `01-create-tables.sql` falha se o schema
`academico` já existir, e `02-insert-data.sql` falha se alguma tabela já
contiver registros. Para uma execução completamente nova, remova o volume do
Docker e repita os passos a partir do item 2:

```bash
docker compose down -v
```

## Decisões e limites desta etapa

- `log_matricula.matricula_id` permanece sem FK, conforme o modelo lógico
  fornecido. A tabela recebe apenas o registro explícito da carga inicial; não
  há gatilho de auditoria neste marco.
- As PKs compostas representam as associações currículo–disciplina e
  disciplina–requisito. O CHECK de pré-requisito impede apenas autorreferência
  direta; o tratamento de ciclos indiretos é feito nas consultas recursivas,
  que usam o caminho percorrido para garantir a terminação.
- O índice único parcial permite no máximo um currículo ativo por curso.
- A restrição EXCLUDE de sala segue o SQL fornecido e tem escopo global: não
  distingue períodos letivos. Por isso a carga cria horários apenas para a
  oferta de 2026/2. Essa regra precisa ser revista se a carga passar a
  reutilizar sala e horário em semestres diferentes.
- A fórmula de média com P3 segue o SQL de referência. Regras acadêmicas
  adicionais não representadas nele devem ser confirmadas antes de alterá-la.
- As notas de 2026/2 simulam o fim do semestre, e não a data atual. A consulta
  08 avalia a elegibilidade **no início** do semestre-alvo: só considera
  aprovações de períodos encerrados antes dele e ignora o resultado simulado da
  matrícula do próprio semestre-alvo.
- O healthcheck do `docker-compose.yml` testa `pg_isready -h 127.0.0.1`, e não o
  socket Unix. Ao inicializar um volume novo, a imagem oficial do PostgreSQL sobe
  um servidor temporário que escuta apenas no socket e depois o desliga. Uma
  verificação pelo socket pode, por isso, reportar "pronto" cedo demais e fazer o
  passo seguinte falhar com `the database system is shutting down`. Só o servidor
  definitivo aceita conexões TCP.
- As duas turmas de Programação Paralela ficam intencionalmente sem matrículas,
  pois nenhum aluno tem aprovação em Sistemas Operacionais. Isso dá à consulta
  04 um caso real de junção externa.

## Autores

Ver [AUTORES.md](AUTORES.md).
