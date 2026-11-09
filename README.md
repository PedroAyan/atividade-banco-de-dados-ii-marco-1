# Sistema de Matrícula Acadêmica | Banco de Dados II

Fizemos um banco para acompanhar a matrícula de um aluno, desde a escolha da turma até o resultado no histórico. No Marco 1, montamos 16 tabelas com 18 chaves estrangeiras e escrevemos 10 consultas. A carga de exemplo tem 120 alunos, 10 turmas, 360 matrículas e 360 históricos. No Marco 2, adicionamos views, índices, permissões por perfil e um script de backup e restauração. Também testamos o que acontece quando dois alunos tentam pegar a última vaga ao mesmo tempo.

## Baixar e preparar na sala

Baixe o projeto em **Code → Download ZIP** no GitHub e extraia a pasta. Para mostrar a estrutura do banco na apresentação, abra o [PDF do diagrama](diagramabancodedadosii.drawio.pdf). Se precisar mexer nele, abra o [arquivo editável](diagramabancodedadosii.drawio) no draw.io.

Para apresentar, vamos usar o pacote do professor, como pede o enunciado. O endereço, a porta e o login estão no guia da disciplina. Depois de conectar, dá para conferir a versão com `SHOW server_version;`. O enunciado indica PostgreSQL 17.

Para ensaiar em casa, usamos um contêiner separado com PostgreSQL 17 e conectamos pelo pgAdmin 4. Os passos a seguir são desse ensaio. Para testar a restauração, também usamos Python 3.10 ou superior.

Na pasta que você extraiu, abra o PowerShell e rode os dois comandos abaixo.

```powershell
docker run -d --name bd2-ensaio-pgadmin -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:55439:5432 postgres:17
docker exec bd2-ensaio-pgadmin pg_isready -h 127.0.0.1 -U postgres -d postgres
```

O primeiro comando cria o contêiner. Repita o segundo até aparecer `accepting connections`. Se já tiver criado esse contêiner, confira em `docker ps -a` e, se estiver parado, use `docker start bd2-ensaio-pgadmin`. Para montar outro ensaio, escolha um nome e uma porta livres e use esses valores nos próximos passos.

No pgAdmin, clique com o botão direito em **Servers** e escolha **Register → Server**. Dê o nome **BD2 – Ensaio** na aba **General**. Na aba **Connection**, preencha o host com `127.0.0.1` e a porta com `55439`. No nosso ensaio, o banco de manutenção, o usuário e a senha são todos `postgres`.

No banco vazio, abra **Databases → postgres → Query Tool**. Use o ícone de pasta para abrir os arquivos da tabela. Rode cada script de instalação e validação inteiro, uma vez, com **▶ Execute script**. Para o passo 3, faça como na seção [Tabelas, consultas e views](#1-tabelas-consultas-e-views) e rode uma consulta por vez.

Se aparecer `ERROR`, pare na primeira mensagem para ver o que deu errado. Se a aba ficar travada na transação com `25P02`, rode só `ROLLBACK;` nela.

| Ordem | Arquivo | O que faz |
| --- | --- | --- |
| 1 | [01-create-tables.sql](sql/01-create-tables.sql) | Cria o schema, as tabelas e as restrições. |
| 2 | [02-insert-data.sql](sql/02-insert-data.sql) | Carrega os dados didáticos. |
| 3 | [03-consultas.sql](sql/03-consultas.sql) | Reúne as dez consultas do Marco 1. No pgAdmin, execute um bloco por vez para ver o resultado em **Data Output**. |
| 4 | [04-views.sql](sql/04-views.sql) | Cria as três views e a view materializada. |
| 5 | [05-indices.sql](sql/05-indices.sql) | Cria quatro índices adicionais, incluindo um parcial. |
| 6 | [06-transacoes.sql](sql/06-transacoes.sql) | Cria as duas funções de matrícula concorrente. |
| 7 | [07-seguranca.sql](sql/07-seguranca.sql) | Cria os perfis, as permissões e a segurança por linha. |
| 8 | [99-validacao.sql](sql/99-validacao.sql) | Confere o Marco 1. Veja as mensagens de validação em **Messages**. |
| 9 | [98-validacao-marco2.sql](sql/98-validacao-marco2.sql) | Confere carga e permissões do Marco 2. |

No script 98, selecione de `BEGIN TRANSACTION READ ONLY;` até o `SELECT ... AS resultado;` e execute. Assim dá para ver o resultado em **Data Output**. Depois, rode o `COMMIT;` separado na mesma aba. Faça as duas validações com a carga original, antes de criar as turmas da demonstração ou depois de apagá-las.

## 1. Tabelas, consultas e views

Na apresentação, dá para começar pelo diagrama e acompanhar uma matrícula na árvore **Schemas → academico → Tables**. A tabela `tb_matricula` liga o aluno à turma. O resultado fica em `tb_historico`.

No [03-consultas.sql](sql/03-consultas.sql), selecione uma consulta inteira, do `SELECT` ou `WITH` até o ponto e vírgula final. Aperte **F5** ou clique em **▶** para ver a grade em **Data Output**. Nas consultas 08 e 10, comece pelo `WITH` e inclua o `SELECT` final. Deixe o `COMMIT;` do arquivo fora da seleção.

Para mostrar como a gente consulta as vagas de cada turma, rode este exemplo.

```sql
SELECT id_turma, vagas_turma, ocupadas, disponiveis
FROM academico.v_vagas
ORDER BY id_turma;
```

Na nossa carga, a turma 5 aparece com 40 vagas, 36 ocupadas e 4 livres. Também temos a `v_oferta` para ver as turmas por disciplina e período, e a `v_historico` para consultar os resultados dos alunos. Já a `mv_indicadores` guarda o resumo da oferta. O proprietário pode atualizar esse resumo quando precisar. O comando e a rotina de atualização estão no [guia das views](docs/VIEWS.md).

## 2. Restrição de integridade

Para mostrar a restrição de vagas, tentamos deixar uma turma com zero vagas. O PostgreSQL barra a mudança e mostra `23514` em **Messages**, com o nome `tb_turma_vagas_turma_check`. Rode o bloco no ensaio e, depois do erro, execute só `ROLLBACK;` na mesma aba.

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

Usamos a turma 1 nesse exemplo porque ela tem 60 matrículas ativas. Em **Data Output → QUERY PLAN**, dá para ver como o PostgreSQL leu a tabela, quantas linhas retornou, quais buffers acessou e quanto tempo levou. O índice `ix_matricula_ativa_turma` cobre as matrículas ativas. Mesmo com ele, pode aparecer `Seq Scan` porque, numa tabela pequena, ler tudo pode sair mais barato. Registramos os [resultados antes e depois dos quatro índices](docs/INDICES.md) e os [planos completos](evidencias/indices.json).

## 4. Disputa pela última vaga

Para simular dois pedidos pela última vaga, usamos duas abas do **Query Tool**, A e B. Abra as duas como `postgres` no mesmo banco de ensaio. Cada aba tem sua própria transação, então selecione só o trecho indicado a cada passo. Comece criando as três turmas de teste uma única vez.

```sql
INSERT INTO academico.tb_turma
    (codigo_turma, id_disciplina, id_periodo_letivo, turno_turma, vagas_turma)
VALUES ('DEMO-ULTIMA', 1, 1, 'NOTURNO', 1),
       ('DEMO-LOCK', 1, 1, 'NOTURNO', 1),
       ('DEMO-SERIAL', 1, 1, 'NOTURNO', 1);
```

### 4.1 Anomalia sem proteção

Primeiro, rode o bloco nas duas abas. As duas devem mostrar uma vaga livre. Deixe as transações abertas para fazer as matrículas no próximo passo.

```sql
BEGIN;
SELECT v.disponiveis
FROM academico.v_vagas v JOIN academico.tb_turma t USING (id_turma)
WHERE t.codigo_turma = 'DEMO-ULTIMA';
```

Matricule o aluno 1 pela **aba A**. Na **aba B**, repita o bloco trocando apenas o `1` depois de `SELECT` por `2`. Cada pedido partiu da mesma informação: ainda havia uma vaga.

```sql
INSERT INTO academico.tb_matricula (id_aluno, id_turma)
SELECT 1, id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-ULTIMA';
COMMIT;
```

Depois de cada cenário, confira as vagas com a consulta abaixo. Nesse primeiro teste, a linha `DEMO-ULTIMA` fica com **1 vaga, 2 ocupadas e −1 disponível**. É aí que aparece a superlotação.

```sql
SELECT t.codigo_turma, v.vagas_turma, v.ocupadas, v.disponiveis
FROM academico.v_vagas v JOIN academico.tb_turma t USING (id_turma)
WHERE t.codigo_turma IN ('DEMO-ULTIMA', 'DEMO-LOCK', 'DEMO-SERIAL')
ORDER BY t.codigo_turma;
```

### 4.2 Correção por bloqueio explícito

Na **aba A**, matricule o primeiro aluno e deixe a transação aberta para segurar o bloqueio da turma.

```sql
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT academico.matricular_bloqueio(1,
    (SELECT id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-LOCK'));
```

Na **aba B**, tente matricular o segundo aluno na mesma turma.

```sql
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT academico.matricular_bloqueio(2,
    (SELECT id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-LOCK'));
```

A **aba B** fica esperando porque A ainda está com a linha da turma bloqueada pelo `FOR UPDATE`. Volte para A e rode só `COMMIT;`. Aí B consegue recontar as matrículas e retorna `Turma lotada` (`P0001`). Rode só `ROLLBACK;` em B e confira as vagas. Em `DEMO-LOCK`, devem aparecer **1 vaga, 1 ocupada e 0 disponíveis**.

### 4.3 Correção por isolamento SERIALIZABLE

Dessa vez, comece pela **aba B**. Consulte a vaga e deixe a transação aberta.

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT v.disponiveis
FROM academico.v_vagas v JOIN academico.tb_turma t USING (id_turma)
WHERE t.codigo_turma = 'DEMO-SERIAL';
```

Na **aba A**, rode o bloco inteiro para matricular o aluno 1 e confirmar a transação.

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT academico.matricular_serializavel(1,
    (SELECT id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-SERIAL'));
COMMIT;
```

Volte à **aba B** e tente matricular o aluno 2 na transação que já está aberta.

```sql
SELECT academico.matricular_serializavel(2,
    (SELECT id_turma FROM academico.tb_turma WHERE codigo_turma = 'DEMO-SERIAL'));
```

A tentativa em B deve falhar com `40001` porque a transação leu a vaga antes de A confirmar a matrícula. Em B, rode só `ROLLBACK;`. Depois, abra outra transação com `BEGIN ISOLATION LEVEL SERIALIZABLE;` e repita o `SELECT`. Dessa vez a função já vê a primeira matrícula e retorna `Turma lotada`. Encerre com `ROLLBACK;` e confira o resultado em `DEMO-SERIAL`: **1 vaga, 1 ocupada e 0 disponíveis**. Contamos como as duas soluções funcionam em [Concorrência](docs/CONCORRENCIA.md).

### Limpar as três turmas de demonstração

Ao terminar, feche as transações nas duas abas. Rode a limpeza no mesmo banco de ensaio em que criou as turmas. A chave estrangeira com `ON DELETE CASCADE` remove junto os históricos das matrículas de teste.

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

Para ver o que muda de um perfil para outro, usamos um login ligado ao aluno 1. Crie esse login uma vez no banco de ensaio, conectado como `postgres`. Se já fez esse passo, use a conexão que você cadastrou.

```sql
BEGIN;
CREATE ROLE aluno_demo_pgadmin LOGIN PASSWORD 'bd2_demo_local';
GRANT aluno TO aluno_demo_pgadmin;
INSERT INTO academico.identidade_aluno (login, id_aluno)
VALUES ('aluno_demo_pgadmin', 1);
COMMIT;
```

Cadastre a conexão **BD2 – Aluno** no pgAdmin. Use o mesmo host, a mesma porta e o mesmo banco da conexão de ensaio, com o usuário `aluno_demo_pgadmin` e a senha de teste `bd2_demo_local`. Abra o Query Tool nas duas conexões e rode a mesma consulta em cada uma.

```sql
SELECT session_user AS login,
       count(*) FILTER (WHERE id_aluno = 1) AS historicos_aluno_1,
       count(*) FILTER (WHERE id_aluno = 2) AS historicos_aluno_2
FROM academico.v_historico;
```

Com as turmas de teste removidas, o administrador vê três históricos de cada aluno. Já na conexão do aluno 1, aparecem os três dele e zero do aluno 2. A consulta é a mesma nas duas abas. A view usa as permissões do login conectado e o RLS filtra as linhas que ele pode ver. Os outros perfis estão no [guia de permissões](docs/SEGURANCA.md).

## 6. Backup e restauração ao vivo

Antes do backup, confira com `python --version` se você tem Python 3.10 ou superior. Se o Windows abrir a Microsoft Store, tente `py -3` ou use o caminho do Python instalado. O script usa só a biblioteca padrão. Durante a cópia, deixe o banco de ensaio sem escritas para que as assinaturas correspondam ao que entrou no backup.

```powershell
$bd2Backup = "backups\ensaio-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
python .\scripts\backup.py backup --container bd2-ensaio-pgadmin --dir $bd2Backup
docker run -d --name bd2-restore-demo -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:55441:5432 postgres:17
docker exec bd2-restore-demo pg_isready -h 127.0.0.1 -U postgres -d postgres
```

Quando aparecer `Backup concluido`, crie o contêiner de destino. Repita o `pg_isready` até aparecer `accepting connections`. Se o nome ou a porta estiverem ocupados, escolha outros e use os novos valores na restauração e no pgAdmin. Rode o próximo comando no **mesmo PowerShell** para aproveitar a variável `$bd2Backup`.

```powershell
python .\scripts\backup.py restore --container bd2-restore-demo --dir $bd2Backup
```

Quando a restauração termina, o script compara as assinaturas do conteúdo e mostra `"restaurado": true` e `"tabelas": 17`. Para conferir também no pgAdmin, cadastre **BD2 – Restaurado** com host `127.0.0.1`, porta `55441`, banco `postgres`, usuário `postgres` e senha `postgres`. Rode a consulta abaixo no original e no restaurado.

```sql
SELECT (SELECT count(*) FROM academico.tb_aluno) AS alunos,
       (SELECT count(*) FROM academico.tb_turma) AS turmas,
       (SELECT count(*) FROM academico.tb_matricula) AS matriculas,
       (SELECT count(*) FROM academico.tb_historico) AS historicos;
```

As contagens precisam bater. Depois de limpar as turmas de teste, espere **120 alunos, 10 turmas, 360 matrículas e 360 históricos** nas duas conexões. A restauração também recupera os papéis e as permissões. Se precisar entrar com esses logins no destino, configure as senhas por lá. O passo a passo completo está no [guia de backup](docs/OPERACAO.md).

## Roteiro para o dia

Para caber nos nove minutos, vamos deixar as conexões prontas e os comandos separados em abas. Planejamos a demonstração assim.

| Tempo | O que mostrar ao vivo |
| --- | --- |
| 1 min | Diagrama ou árvore do pgAdmin, uma consulta ou view e a restrição rejeitando a turma com zero vagas. |
| 1 min | Um `EXPLAIN ANALYZE` e a comparação de índices antes/depois. |
| 3 min | Turma superlotada sem proteção e as duas correções com duas sessões. |
| 1 min | Mesma consulta de histórico como administrador e como aluno. |
| 3 min | Restauração em destino vazio e conferência no pgAdmin. |

No dia, vamos levar o backup pronto e deixar o contêiner de destino vazio e já iniciado. Ao vivo, mostramos a restauração e comparamos os dados. Depois temos cerca de nove minutos de arguição individual. Cada um precisa saber explicar também as partes dos colegas.

Fizemos esse ensaio com PostgreSQL 17.11 e guardamos os resultados em [evidencias/](evidencias/). Falta repetir no pacote da disciplina. Os nomes do grupo e a divisão de tarefas registrada estão em [AUTORES.md](AUTORES.md).

## Validação automatizada opcional

Também deixamos um caminho automatizado para quem quiser repetir os testes. Comece com outro banco de ensaio vazio, porque o validador também instala os objetos. Na raiz do projeto, crie um ambiente Python, instale as [dependências](scripts/requirements.txt) e coloque os dados da conexão em `BD2_DSN`. Rode `scripts/validar.py` nas etapas `base`, `views`, `indices`, `concorrencia` e `seguranca`, nessa ordem. Cada etapa grava o resultado em `evidencias/`. Os testes que já fizemos estão descritos no [registro de verificação](evidencias/STATUS.md).

## Decisões e limites desta etapa

- Seguimos o modelo lógico e deixamos `tb_log_matricula.id_matricula` sem chave estrangeira. Por enquanto, a tabela tem só o registro que inserimos na carga inicial. Ainda não temos gatilho de auditoria.
- Usamos chaves primárias compostas nas relações entre currículo e disciplina e entre disciplina e pré-requisito. O `CHECK` impede que uma disciplina seja pré-requisito de si mesma. Se houver um ciclo passando por várias disciplinas, a consulta recursiva usa o caminho já percorrido para evitar um loop.
- Com o índice único parcial, cada curso pode ter no máximo um currículo ativo.
- Mantivemos a restrição de salas do SQL fornecido. Ela impede a sobreposição de horários sem distinguir semestres, então só colocamos horários na oferta de 2026/2. Se formos reutilizar salas e horários em outros semestres, precisamos rever essa regra.
- Para calcular a média com P3, seguimos a fórmula do SQL de referência. Antes de mudar a fórmula, precisamos confirmar se a disciplina prevê alguma regra a mais.
- Preenchemos as notas de 2026/2 como se o semestre já tivesse acabado. A consulta 08 responde o que o aluno poderia cursar **no início** do semestre escolhido. Por isso, ela só conta aprovações de semestres que já tinham acabado e ignora a nota simulada do próprio semestre.
- No `docker-compose.yml`, usamos `pg_isready -h 127.0.0.1` porque o PostgreSQL sobe primeiro um servidor temporário que aceita conexões pelo socket Unix. Se checarmos só o socket, o contêiner pode parecer pronto e o próximo passo falhar com `the database system is shutting down`. A conexão TCP só fica disponível quando o servidor definitivo sobe.
- Deixamos as duas turmas de Programação Paralela vazias porque nenhum aluno passou em Sistemas Operacionais. Na consulta 04, dá para ver que a junção externa inclui essas turmas mesmo sem matrículas.

## Empacotamento

O ZIP do GitHub já traz o material da entrega, incluindo os scripts, o diagrama e as evidências. Se você clonou o repositório, também pode rodar `python scripts/empacotar.py` para gerar um ZIP na pasta `entrega/`. Deixamos backups, ambientes Python e arquivos pessoais fora da publicação.
