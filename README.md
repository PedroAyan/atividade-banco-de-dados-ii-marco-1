# Sistema de Matrícula Acadêmica | Banco de Dados II

Projeto dos Marcos 1 e 2. O Marco 1 tem 16 tabelas, 18 chaves estrangeiras, 120 alunos, 10 turmas, 360 matrículas e 360 históricos, além de 10 consultas. O Marco 2 acrescenta views, índices, duas soluções para a disputa pela última vaga, permissões por perfil e recuperação por backup.

## Baixar e preparar na sala

No GitHub, use **Code → Download ZIP** e extraia o ZIP inteiro. Abra este README na pasta extraída e tenha o [PDF do diagrama](diagramabancodedadosii.drawio.pdf) disponível para mostrar a estrutura. O [arquivo Draw.io](diagramabancodedadosii.drawio) é a versão editável.

O enunciado pede o **contêiner PostgreSQL 17 fornecido pela disciplina**. Para a apresentação oficial, siga o guia do professor para iniciar o pacote e use o host, a porta e as credenciais do guia. Confirme a versão com `SHOW server_version;`. Os comandos abaixo montam um **ensaio local separado** para praticar do zero. Eles usam Docker Desktop, pgAdmin 4 e Python 3.10+ para o script de backup.

Abra o PowerShell na pasta extraída e execute:

```powershell
docker run -d --name bd2-ensaio-pgadmin -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:55439:5432 postgres:17
docker exec bd2-ensaio-pgadmin pg_isready -h 127.0.0.1 -U postgres -d postgres
```

Repita só a segunda linha até aparecer `accepting connections`. Se já houver um contêiner de ensaio com esse nome, confira se é o seu com `docker ps -a` e inicie-o com `docker start bd2-ensaio-pgadmin` se estiver parado. Para um novo ensaio, escolha nome e porta livres e use os mesmos valores nos passos seguintes.

No pgAdmin, clique com o botão direito em **Servers → Register → Server**. Use **BD2 – Ensaio** em **General**. Em **Connection**, use host `127.0.0.1`, porta `55439`, banco de manutenção `postgres`, usuário `postgres` e senha `postgres`. Essas credenciais são apenas para o ensaio local.

Abra **Databases → postgres → Query Tool**. Pelo ícone de pasta, abra cada SQL na ordem abaixo e clique em **▶ Execute script** com o arquivo inteiro, sem seleção. Instale uma vez em um banco vazio. Se aparecer `ERROR`, pare e veja a primeira mensagem. Para liberar uma aba com `25P02`, rode só `ROLLBACK;` nela.

| Ordem | Arquivo | O que faz |
| --- | --- | --- |
| 1 | [01-create-tables.sql](sql/01-create-tables.sql) | Cria o schema, as tabelas e as restrições. |
| 2 | [02-insert-data.sql](sql/02-insert-data.sql) | Carrega os dados didáticos. |
| 3 | [04-views.sql](sql/04-views.sql) | Cria as três views e a view materializada. |
| 4 | [05-indices.sql](sql/05-indices.sql) | Cria quatro índices adicionais, incluindo um parcial. |
| 5 | [06-transacoes.sql](sql/06-transacoes.sql) | Cria as duas funções de matrícula concorrente. |
| 6 | [07-seguranca.sql](sql/07-seguranca.sql) | Cria os perfis, as permissões e a segurança por linha. |
| 7 | [99-validacao.sql](sql/99-validacao.sql) | Confere o Marco 1. Veja as mensagens de validação em **Messages**. |
| 8 | [98-validacao-marco2.sql](sql/98-validacao-marco2.sql) | Confere carga e permissões do Marco 2. |

Para mostrar o resultado do `98` em **Data Output**, selecione o arquivo desde `BEGIN TRANSACTION READ ONLY;` até o `SELECT ... AS resultado;`, deixando o `COMMIT;` final de fora. Execute a seleção. Depois execute só `COMMIT;` na mesma aba. Rode as validações antes de criar as turmas de demonstração ou após a limpeza indicada adiante.

## 1. Tabelas, consultas e views

Em **Schemas → academico → Tables**, mostre como `tb_aluno` e `tb_turma` se ligam por `tb_matricula` e como `tb_historico` guarda o resultado da matrícula. Use o PDF do diagrama para acompanhar as conexões.

Abra [03-consultas.sql](sql/03-consultas.sql) no Query Tool. Para ensaiar as dez consultas, selecione **um bloco completo por vez**, do `SELECT` ou `WITH` até o ponto e vírgula que encerra a consulta. Clique em **▶** ou pressione **F5** e veja **Data Output**. A consulta 08 começa em `WITH RECURSIVE` e termina em `ORDER BY c.periodo_curriculo_disciplina,c.codigo_disciplina;`. A 10 começa em `WITH medias_semestrais AS (` e termina em `FROM evolucao ORDER BY matricula_aluno,ano_periodo_letivo,semestre_periodo_letivo;`. O `COMMIT;` fica fora das seleções.

Para mostrar uma view, rode:

```sql
SELECT id_turma, vagas_turma, ocupadas, disponiveis
FROM academico.v_vagas
ORDER BY id_turma;
```

A turma 5 tem 40 vagas, 36 ocupadas e 4 disponíveis na carga original. As outras views são `v_oferta` e `v_historico`. Os indicadores em `mv_indicadores` ficam armazenados e podem ser atualizados pelo proprietário com `REFRESH MATERIALIZED VIEW CONCURRENTLY academico.mv_indicadores;`. Veja a [política de atualização](docs/VIEWS.md).

## 2. Restrição de integridade

No banco de ensaio, execute o bloco abaixo. Em **Messages**, o erro `23514` da restrição `tb_turma_vagas_turma_check` é o resultado esperado. Depois execute **só `ROLLBACK;`** na mesma aba.

```sql
BEGIN;
UPDATE academico.tb_turma
SET vagas_turma = 0
WHERE id_turma = 1;
```

## 3. Plano de execução e índice parcial

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM academico.tb_matricula
WHERE id_turma = 1 AND status_matricula = 'MATRICULADO';
```

Em **Data Output → QUERY PLAN**, mostre o tipo de leitura, as linhas retornadas, os buffers e o tempo. A turma 1 tem 60 matrículas ativas. Se aparecer `Seq Scan`, explique que o PostgreSQL escolhe o plano pelo custo estimado e pode preferir ler uma tabela pequena inteira. O índice parcial `ix_matricula_ativa_turma` contém as matrículas ativas. Mostre também os [resultados antes e depois dos quatro índices](docs/INDICES.md) e os [planos completos](evidencias/indices.json).

## 4. Disputa pela última vaga

Faça estes testes **no banco de ensaio isolado**. Abra **dois Query Tools novos**, A e B, no mesmo banco como `postgres`. Cada aba tem sua própria transação. Use a seleção para executar apenas o trecho indicado. Crie as três turmas de teste uma única vez:

```sql
INSERT INTO academico.tb_turma
    (codigo_turma, id_disciplina, id_periodo_letivo, turno_turma, vagas_turma)
VALUES ('DEMO-ULTIMA', 1, 1, 'NOTURNO', 1),
       ('DEMO-LOCK', 1, 1, 'NOTURNO', 1),
       ('DEMO-SERIAL', 1, 1, 'NOTURNO', 1);
```

### 4.1 Anomalia sem proteção

Execute o bloco abaixo nas **duas abas** antes de matricular qualquer aluno. Ambas devem mostrar uma vaga livre.

```sql
BEGIN;
SELECT v.disponiveis
FROM academico.v_vagas v JOIN academico.tb_turma t USING (id_turma)
WHERE t.codigo_turma = 'DEMO-ULTIMA';
```

Na **aba A**, execute o bloco abaixo. Depois execute na **aba B**, trocando somente o `1` após `SELECT` por `2`. As duas abas tentam matricular alunos diferentes na turma que ambas viram com uma vaga.

```sql
INSERT INTO academico.tb_matricula (id_aluno, id_turma)
SELECT 1, id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-ULTIMA';
COMMIT;
```

Execute esta consulta após cada cenário. No primeiro, a linha `DEMO-ULTIMA` fica com **1 vaga, 2 ocupadas e −1 disponível**.

```sql
SELECT t.codigo_turma, v.vagas_turma, v.ocupadas, v.disponiveis
FROM academico.v_vagas v JOIN academico.tb_turma t USING (id_turma)
WHERE t.codigo_turma IN ('DEMO-ULTIMA', 'DEMO-LOCK', 'DEMO-SERIAL')
ORDER BY t.codigo_turma;
```

### 4.2 Correção por bloqueio explícito

Na **aba A**, execute o bloco abaixo. Deixe a transação aberta.

```sql
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT academico.matricular_bloqueio(1,
    (SELECT id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-LOCK'));
```

Na **aba B**, execute o bloco:

```sql
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT academico.matricular_bloqueio(2,
    (SELECT id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-LOCK'));
```

Enquanto B estiver esperando, volte à **aba A** e execute só `COMMIT;`. A aba B vai mostrar `Turma lotada` (`P0001`). Execute só `ROLLBACK;` na B. Rode de novo a consulta de vagas. A linha `DEMO-LOCK` deve mostrar **1 vaga, 1 ocupada e 0 disponíveis**. O `FOR UPDATE` faz a segunda sessão esperar e só então recontar as matrículas.

### 4.3 Correção por isolamento SERIALIZABLE

Na **aba B**, leia primeiro a vaga e mantenha a transação aberta:

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT v.disponiveis
FROM academico.v_vagas v JOIN academico.tb_turma t USING (id_turma)
WHERE t.codigo_turma = 'DEMO-SERIAL';
```

Na **aba A**, execute o bloco inteiro para matricular o aluno 1 e confirmar:

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT academico.matricular_serializavel(1,
    (SELECT id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-SERIAL'));
COMMIT;
```

Na **aba B**, dentro da transação aberta, tente matricular o aluno 2:

```sql
SELECT academico.matricular_serializavel(2,
    (SELECT id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-SERIAL'));
```

O resultado esperado é `40001`. Execute só `ROLLBACK;` na B. Em seguida, na B, abra uma transação nova com `BEGIN ISOLATION LEVEL SERIALIZABLE;` e repita o `SELECT` acima. A retentativa deve mostrar `Turma lotada` porque agora enxerga a primeira matrícula. Encerre com `ROLLBACK;`. A linha `DEMO-SERIAL` fica com **1 vaga, 1 ocupada e 0 disponíveis**. Compare os dois métodos em [Concorrência](docs/CONCORRENCIA.md).

### Limpar as três turmas de demonstração

Depois de mostrar o resultado, encerre as transações nas duas abas. Execute este bloco apenas no ensaio, onde esses três códigos foram criados para os testes. A exclusão das matrículas de teste também remove os históricos ligados a elas pela FK com `ON DELETE CASCADE`.

```sql
BEGIN;
DELETE FROM academico.tb_matricula m
USING academico.tb_turma t
WHERE m.id_turma = t.id_turma
  AND t.id_disciplina = 1 AND t.id_periodo_letivo = 1
  AND t.codigo_turma IN ('DEMO-ULTIMA', 'DEMO-LOCK', 'DEMO-SERIAL');

DELETE FROM academico.tb_turma
WHERE id_disciplina = 1 AND id_periodo_letivo = 1
  AND codigo_turma IN ('DEMO-ULTIMA', 'DEMO-LOCK', 'DEMO-SERIAL');
COMMIT;
```

## 5. Segurança por linha (RLS)

No ensaio, como `postgres`, crie uma vez o login didático. Se já foi criado e funciona, use a conexão existente.

```sql
BEGIN;
CREATE ROLE aluno_demo_pgadmin LOGIN PASSWORD 'bd2_demo_local';
GRANT aluno TO aluno_demo_pgadmin;
INSERT INTO academico.identidade_aluno (login, id_aluno)
VALUES ('aluno_demo_pgadmin', 1);
COMMIT;
```

Registre **BD2 – Aluno** no pgAdmin com o mesmo host, porta e banco do ensaio, usuário `aluno_demo_pgadmin` e senha didática `bd2_demo_local`. Abra o Query Tool nessa conexão e também na conexão de administrador. Execute a mesma consulta nas duas:

```sql
SELECT session_user AS login,
       count(*) FILTER (WHERE id_aluno = 1) AS historicos_aluno_1,
       count(*) FILTER (WHERE id_aluno = 2) AS historicos_aluno_2
FROM academico.v_historico;
```

Com a carga original e após a limpeza das turmas de teste, o administrador vê **3 e 3**. O login do aluno 1 vê **3 e 0**. Mostre que a consulta é a mesma e que o login muda. A view usa as permissões do usuário que chama a consulta e o RLS filtra as linhas. Veja [os papéis e as permissões](docs/SEGURANCA.md).

## 6. Backup e restauração ao vivo

No PowerShell, na pasta extraída, confirme que `python --version` mostra Python 3.10 ou superior. Se o Windows abrir a Microsoft Store, use o caminho do Python instalado ou `py -3` no lugar de `python`. O script de backup usa apenas a biblioteca padrão. Pare as escritas no banco de ensaio durante a cópia.

```powershell
$bd2Backup = "backups\ensaio-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
python .\scripts\backup.py backup --container bd2-ensaio-pgadmin --dir $bd2Backup
docker run -d --name bd2-restore-demo -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:55441:5432 postgres:17
docker exec bd2-restore-demo pg_isready -h 127.0.0.1 -U postgres -d postgres
```

Espere `Backup concluido` antes de criar o destino. Repita só `pg_isready` até `accepting connections`. Se o nome ou a porta já estiverem ocupados, escolha outros para o novo destino. No **mesmo PowerShell**, execute:

```powershell
python .\scripts\backup.py restore --container bd2-restore-demo --dir $bd2Backup
```

Mostre `"restaurado": true` e `"tabelas": 17`. O script compara as assinaturas do conteúdo das tabelas. No pgAdmin, registre **BD2 – Restaurado** com host `127.0.0.1`, porta `55441`, banco `postgres`, usuário `postgres` e senha `postgres`. Execute no original e no restaurado:

```sql
SELECT (SELECT count(*) FROM academico.tb_aluno) AS alunos,
       (SELECT count(*) FROM academico.tb_turma) AS turmas,
       (SELECT count(*) FROM academico.tb_matricula) AS matriculas,
       (SELECT count(*) FROM academico.tb_historico) AS historicos;
```

As duas conexões devem retornar os mesmos números. Se fez a limpeza das turmas de teste, espere **120 | 10 | 360 | 360**. O backup recupera os papéis e as permissões. As senhas de login são configuradas separadamente no destino se forem necessárias. Veja [o procedimento completo](docs/OPERACAO.md).

## Roteiro para o dia

Prepare as conexões e deixe os comandos separados em abas antes da apresentação. Ensaiem os **9 minutos de demonstração** com esta divisão aproximada:

| Tempo | O que mostrar ao vivo |
| --- | --- |
| 1 min | Diagrama ou árvore do pgAdmin, uma consulta ou view e a restrição rejeitando a turma com zero vagas. |
| 1 min | Um `EXPLAIN ANALYZE` e a comparação de índices antes/depois. |
| 3 min | Turma superlotada sem proteção e as duas correções com duas sessões. |
| 1 min | Mesma consulta de histórico como administrador e como aluno. |
| 3 min | Restauração em destino vazio e conferência no pgAdmin. |

Para a restauração ao vivo, já deixe o arquivo de backup gerado e o contêiner de destino **vazio e iniciado**. Durante a apresentação, execute a restauração e confira os dados. Depois vêm aproximadamente **9 minutos de arguição individual**. Cada integrante deve saber explicar também as frentes dos colegas.

Os testes técnicos anteriores estão em [evidencias/](evidencias/). Os testes de demonstração foram exercitados no ensaio local com PostgreSQL 17.11. Confirme o procedimento no pacote oficial da disciplina antes de apresentar. Veja [AUTORES.md](AUTORES.md) para as responsabilidades registradas e confirme com o professor a composição do grupo.

## Validação automatizada opcional

Em outro ensaio vazio, na raiz do projeto, crie um ambiente Python, instale [scripts/requirements.txt](scripts/requirements.txt) e configure `BD2_DSN` com os dados desse banco. Execute `scripts/validar.py` com as etapas `base`, `views`, `indices`, `concorrencia` e `seguranca`, nessa ordem. Cada etapa grava evidências em `evidencias/`. Use essa sequência como alternativa à instalação manual no mesmo banco, pois ela também instala os objetos. O [registro de verificação](evidencias/STATUS.md) descreve os testes anteriores.

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

## Empacotamento

O ZIP do GitHub já contém o README, os SQL, os scripts, o diagrama e as evidências versionadas. Em um clone Git, `python scripts/empacotar.py` também gera um ZIP local em `entrega/`. Backups, ambientes Python e arquivos particulares ficam fora da publicação.
