# Sistema de Matrícula Acadêmica — Marcos 1 e 2

Projeto de Banco de Dados II. O Marco 1 foi preservado: 16 tabelas, carga de 120 alunos, dez turmas, 360 matrículas e históricos, dez consultas e diagrama. O Marco 2 adiciona três views, indicadores materializados, quatro índices medidos, disputa de vagas com duas soluções alternativas, papéis/RLS e recuperação reproduzível.

## Ambiente e limites

Os testes técnicos foram executados em **PostgreSQL 17.11**, em contêineres novos e isolados. Isso **não é validação oficial**. O enunciado informa 17, mas o guia anterior registrava 16; o pacote Docker efetivamente fornecido pela disciplina não está disponível para confirmar a divergência. Consulte [ambiente e ferramentas](docs/ambiente-e-ferramentas.md). Na apresentação oficial, confirmar a imagem do pacote e `SHOW server_version`, e executar no pgAdmin conforme o professor. Não substituir nem apagar o ambiente da disciplina.

Autores e responsabilidades existentes: [AUTORES.md](AUTORES.md). A composição de dupla ou eventual terceiro integrante e as responsabilidades formais restantes dependem de confirmação; nenhum nome ou contribuição foi presumido.

## Execução técnica isolada do zero (PowerShell)

Pré-requisitos: Git, Docker Desktop em execução e Python 3.10+. Execute na raiz do clone. Use nomes/portas novos se já estiverem ocupados. A imagem 17 é o alvo técnico deste repositório, sujeito à confirmação do ambiente oficial.

```powershell
git clone https://github.com/PedroAyan/atividade-banco-de-dados-ii-marco-1.git
cd atividade-banco-de-dados-ii-marco-1
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r scripts/requirements.txt
docker run -d --name bd2-ensaio-novo -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:55439:5432 postgres:17
docker exec bd2-ensaio-novo pg_isready -h 127.0.0.1 -U postgres
```

Aguarde `accepting connections` por TCP antes de continuar (a primeira inicialização pode levar alguns segundos). Senha acima é exclusivamente didática, em localhost. O banco de ensaio se chama `postgres`; o Compose original continua disponível para o Marco 1 com `matricula_academica`, sem alterações.

```powershell
$env:BD2_DSN='host=127.0.0.1 port=55439 dbname=postgres user=postgres password=postgres'
.\.venv\Scripts\python.exe scripts/validar.py base
.\.venv\Scripts\python.exe scripts/validar.py views
.\.venv\Scripts\python.exe scripts/validar.py indices
.\.venv\Scripts\python.exe scripts/validar.py concorrencia
.\.venv\Scripts\python.exe scripts/validar.py seguranca
```

Pare se qualquer comando falhar. O validador instala cada etapa e registra evidências reais em `evidencias/`; reexecutar etapas de criação no mesmo banco não é suportado. Crie outro contêiner para repetir. `base` recusa schema existente. A etapa de concorrência cria/remove exclusivamente suas turmas artificiais no banco de ensaio. A segurança cria um login de teste com senha didática, nunca executar esses testes no banco de trabalho.

Para instalação sem testes, execute no Query Tool do pgAdmin como administrador, uma vez em destino novo, nesta ordem:

1. `sql/01-create-tables.sql` — DDL original; requer btree_gist.
2. `sql/02-insert-data.sql` — carga original; recusa tabelas preenchidas.
3. `sql/03-consultas.sql` e `sql/99-validacao.sql` — consultas e validação do Marco 1.
4. `sql/04-views.sql` — views e materialized view.
5. `sql/05-indices.sql` — quatro índices adicionais, incluindo parcial.
6. `sql/06-transacoes.sql` — funções atômicas de matrícula.
7. `sql/07-seguranca.sql` — perfis, GRANT/REVOKE e RLS; exige nomes de papéis livres no cluster.
8. `sql/98-validacao-marco2.sql` — verificações de leitura como administrador sobre a carga didática.

Os SQL 98/99 são verificações, não migrações. As funções não substituem todas as regras acadêmicas futuras (por exemplo elegibilidade por pré-requisito); seu escopo é a disputa da vaga e criação atômica de matrícula/histórico. No acesso operacional, a secretaria usa somente a solução com bloqueio. SERIALIZABLE é uma alternativa demonstrada separadamente; não misturar protocolos de escrita.

## Evidências e demonstração

[Views e atualização](docs/VIEWS.md), [índices e medições](docs/INDICES.md), [concorrência e retentativa](docs/CONCORRENCIA.md), [papéis e RLS](docs/SEGURANCA.md), [backup/restauração](docs/OPERACAO.md) e [roteiro de apresentação](docs/APRESENTACAO.md).

Os JSON em `evidencias/` guardam versão, planos `EXPLAIN (ANALYZE, BUFFERS)` antes/depois, lotação, isolamento por login e restauração. O [estado de verificação](evidencias/STATUS.md) explicita limites. A carga pequena não permite generalizar ganhos de desempenho.

## Backup e recuperação

Siga [o procedimento completo](docs/OPERACAO.md). O utilitário trabalha em contêiner dedicado e no banco `postgres`, grava dump binário sem corrupção de encoding, exporta papéis sem senhas, verifica SHA256 e só restaura em destino novo. Nunca remove dados ou volumes.

```powershell
python scripts/backup.py backup --container bd2-ensaio-novo --dir backups/ensaio-novo
docker run -d --name bd2-recuperacao-nova -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:55441:5432 postgres:17
docker exec bd2-recuperacao-nova pg_isready -h 127.0.0.1 -U postgres
# Após accepting connections:
python scripts/backup.py restore --container bd2-recuperacao-nova --dir backups/ensaio-novo
$env:BD2_RESTORE_DSN='host=127.0.0.1 port=55441 dbname=postgres user=postgres password=postgres'
.\.venv\Scripts\python.exe scripts/verificar-restauracao.py
```

O teste complementar exige o login artificial da etapa `seguranca`; compara catálogos/permissões e reprovisiona a senha didática desse login no destino para provar RLS restaurado. Dumps e credenciais ficam fora do Git. Para recomeçar, escolha novo nome/porta: não apague o banco nem volumes anteriores.

## Entrega

O repositório contém SQL numerado, documentação, evidências e scripts públicos. `python scripts/empacotar.py` gera ZIP local em `entrega/` somente com arquivos versionados permitidos e registra SHA256. Documentos privados, dumps e ambientes Python não entram. O roteiro de apresentação cobre integridade, anomalia, correções, plano, RLS e restauração. Confirmar grupo e ambiente oficial antes da entrega acadêmica.

## Decisões e limites desta etapa

- `tb_log_matricula.id_matricula` permanece sem FK, conforme o modelo lógico
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
