# Sistema de Matrícula Acadêmica

## Descrição

Projeto desenvolvido para a disciplina de Banco de Dados II.

O projeto consiste no desenvolvimento de um banco de dados para um Sistema de Matrícula Acadêmica, contemplando o gerenciamento de alunos, cursos, disciplinas, turmas e matrículas.

## Objetivo

Desenvolver um banco de dados relacional capaz de armazenar e gerenciar informações acadêmicas, aplicando conceitos de banco de dados estudados durante a disciplina.

## Tecnologias

- PostgreSQL 17
- Docker
- SQL
- Git/GitHub

## Modelo Inicial

O diagrama abaixo apresenta uma visão inicial do domínio do Sistema de Matrícula Acadêmica.

![Modelo inicial](docs/modelo/modelo-relacional.png)

## Status

🚧 Em desenvolvimento

## Estrutura do banco — Marco 1

O arquivo `sql/01-create-tables.sql` cria o schema `academico`, os tipos,
os domínios, as 16 tabelas e as restrições declarativas do modelo fornecido.
A implementação usa o modelo lógico e o SQL de referência do professor.

### Executar no Git Bash, na pasta do repositório

1. Inicie o ambiente:

```bash
docker compose up -d
```

2.  Aguarde o PostgreSQL aceitar conexões:

```bash
docker compose exec postgres pg_isready -U postgres -d matricula_academica
```

3. Execute o DDL **uma única vez em um banco novo**:

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d matricula_academica < sql/01-create-tables.sql
```


4. Carregar os dados

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d matricula_academica < sql/02-insert-data.sql
```

### passo 6 — Executar as 10 consultas

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d matricula_academica < sql/03-consultas.sql
```

5. Liste as tabelas:

```bash
docker compose exec -T postgres psql -X -U postgres -d matricula_academica -c '\dt academico.*'
```


O resultado esperado é uma lista de 16 tabelas. O Docker Compose atual não
executa os scripts SQL automaticamente. O script usa uma transação e não
apaga dados: se `academico` já existir, ele falhará sem recriar o schema.

### Decisões e limites desta etapa

- `log_matricula.matricula_id` permanece sem FK, conforme o modelo fornecido.
- As PKs compostas representam as associações currículo–disciplina e
  disciplina–requisito. O CHECK de pré-requisito impede apenas autorreferência
  direta; o tratamento de ciclos indiretos deve ser considerado nas consultas.
- O índice único parcial permite no máximo um currículo ativo por curso.
- A exclusão de horários segue o SQL fornecido e tem escopo global: não
  distingue semestres. Essa regra precisa ser revista se a carga reutilizar
  sala e horário em períodos diferentes.
- A fórmula de média com P3 segue o SQL de referência. Regras acadêmicas
  adicionais não representadas nele devem ser confirmadas antes de alterá-la.
- A disputa pela última vaga e a geração automática de auditoria não são
  implementadas neste arquivo. A tabela de auditoria começa vazia.


