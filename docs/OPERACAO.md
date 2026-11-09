# Backup e restauração

Requer Docker em execução, Python 3.10+ e contêineres oficiais PostgreSQL 17 com administrador postgres. No script, passamos o dump binário como bytes pelo `subprocess` para evitar problemas com o redirecionamento no PowerShell. No nosso ensaio, usamos o banco `postgres` em um contêiner exclusivo. Para banco com outro nome, adaptar e revisar os parâmetros -d antes de usar; não apontar ao serviço do Marco 1.

Durante o backup interromper escritas no ambiente de ensaio até concluir o manifesto: pg_dump tem snapshot consistente, mas as assinaturas posteriores precisam corresponder ao mesmo estado. Nunca usar este script em cluster compartilhado: o backup de papéis inclui o cluster inteiro. O diretório de saída deve ser novo.

```powershell
python scripts/backup.py backup --container bd2-marco2-20261106 --dir backups/ensaio-novo
docker run -d --name bd2-recuperacao-nova -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:55441:5432 postgres:17
docker exec bd2-recuperacao-nova pg_isready -h 127.0.0.1 -U postgres
# Aguardar retorno accepting connections antes do próximo comando.
python scripts/backup.py restore --container bd2-recuperacao-nova --dir backups/ensaio-novo
```

O procedimento não usa --clean, DROP DATABASE nem remoção de volumes. Recusa destino com schema academico, tabelas de usuário ou papéis não internos além do postgres. Confere versão principal e SHA256; restaura papéis (sem senhas), depois objetos/dados/ACLs via pg_restore em transação única e falha no primeiro erro. A conta bootstrap postgres não é recriada nem alterada. Se falhar após criar papéis, preservar o destino para diagnóstico e repetir em outro contêiner novo; não limpar o destino automaticamente.

O manifesto compara contagens e hashes de todas as linhas das 17 tabelas (16 originais e vínculo de identidade). A evidência da restauração está em evidencias/restauracao.json; o teste complementar usa um login restaurado para provar RLS e compara objetos/catálogo. pg_restore também recupera sequências, views, índices, políticas e permissões. Proteger o diretório de backup, guardar cópia fora da máquina com retenção definida pela equipe e testar recuperação periodicamente. Não publicar dumps nem senhas; backups/ é ignorado pelo Git. Este ensaio não implementa PITR/WAL nem teste de desastre físico.

As senhas dos logins não são exportadas. Reprovisionar no destino com \password no psql, ou por gestão de segredos. O teste usa apenas senha didática em contêiner local isolado.

Durante o teste, vimos que o `pg_dump` deixa de fora as ACLs das funções internas geradas para tipos `RANGE`. Por isso, reaplicamos `REVOKE` para `PUBLIC` em todas as funções de `academico`, como no script 07, antes de comparar o catálogo. O dump preserva as permissões concedidas a papéis específicos nas funções da aplicação.
