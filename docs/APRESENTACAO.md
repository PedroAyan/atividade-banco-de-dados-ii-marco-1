# Roteiro de apresentação do Marco 2

1. Mostrar ambiente, versão e resultados de 99/98; confirmar as 16 tabelas originais e carga 120/10/360/360.
2. Mostrar oferta, vagas, histórico e indicadores; executar refresh concorrente como proprietário e explicar a defasagem diária.
3. Abrir indices.json e INDICES.md: mesma consulta antes/depois, buffers, plano escolhido e mediana. Explicar por que uma tabela pequena pode continuar com Seq Scan.
4. Em ambiente temporário novo, executar a etapa concorrencia: duas conexões, duas matrículas para uma vaga na anomalia; uma só em cada correção. Mostrar 40001, rollback e retentativa; explicar que os protocolos são alternativas e secretaria só recebe bloqueio.
5. Conectar por TCP como teste_aluno, consultar próprios históricos e de outro aluno; tentar escrever ou acessar o vínculo. Mostrar permissões da secretaria e coordenação.
6. Executar backup e restore em outro contêiner vazio conforme OPERACAO.md, mostrar igualdade das assinaturas e login restaurado com RLS. Não apagar o ambiente de trabalho.

Não distribuir falas ou autoria presumida. A equipe deve confirmar composição e responsabilidades com o professor. A validação oficial em pgAdmin e a versão do pacote da disciplina continuam pendentes. O PDF do diagrama ainda precisa ser conferido e exportado pelo draw.io, conforme o guia original.
