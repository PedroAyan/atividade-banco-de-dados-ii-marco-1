# Papéis e RLS

Execute 07 uma vez como administrador em cluster novo, após 04 e 06. Os papéis são NOLOGIN e não devem preexistir: colisões abortam toda a transação. Em cluster compartilhado, o administrador precisa revisar a integração sem substituir papéis existentes.

`aluno` lê oferta e somente suas matrículas/históricos; `secretaria` lê dados administrativos e matricula exclusivamente pelas funções; `coordenacao` lê e atualiza notas, frequência e situação. Nenhum deles insere diretamente matrículas, muda capacidade ou altera vínculos de identidade. Coordenação é um perfil administrativo de confiança, com leitura de todos os alunos. O schema não concede CREATE. Superusuário e proprietário ignoram RLS; por isso a prova usa login sem privilégios, e não SELECT como postgres.

O administrador cria um LOGIN por pessoa, concede o perfil e vincula a identidade em `academico.identidade_aluno(login,id_aluno)`. Exemplo: CREATE ROLE estudante_1 LOGIN; GRANT aluno TO estudante_1; INSERT INTO academico.identidade_aluno VALUES ('estudante_1',1);. Defina a senha fora de scripts públicos (psql: \password estudante_1). Conecte por TCP como estudante_1 e consulte v_historico. O mapeamento usa session_user, que SET ROLE e variáveis personalizadas não substituem. Login sem mapeamento vê zero linhas. Pools com login compartilhado não são suportados por este modelo.

O histórico usa view security_invoker e RLS nas duas tabelas subjacentes. A função de identidade é SECURITY DEFINER com search_path fixo e somente retorna o próprio vínculo; sua tabela não é exposta. As funções de matrícula também têm search_path fixo, não usam SQL dinâmico; somente a função de bloqueio é liberada à secretaria. Permissões PUBLIC são revogadas.

Teste reproduzível: etapa seguranca do validador em cluster isolado; cria apenas o login artificial teste_aluno com senha didática isolado. Nunca execute esse teste em cluster de produção. O JSON registra três históricos próprios, zero alheios, negações de escrita e leitura do mapeamento, além da leitura administrativa. Backup de papéis não inclui senhas; reprovisionar credenciais no destino.
