-- Marco 1 — Validação da entrega. PostgreSQL 17.
-- Executar DEPOIS de 01-create-tables.sql e 02-insert-data.sql.
-- Este arquivo NÃO faz parte da criação do banco: 01, 02 e 03 continuam sendo
-- a ordem normal de execução. Aqui apenas se confere o que já foi entregue.
--
-- É somente leitura: abre uma transação READ ONLY e não escreve em nenhuma
-- tabela. Pode ser executado quantas vezes quiser, sem efeito sobre os dados.
--
-- Use com ON_ERROR_STOP=1. Se alguma verificação falhar, o script encerra com
-- erro e lista de uma vez TODOS os problemas encontrados.
BEGIN READ ONLY;
SET LOCAL search_path TO academico, public;

DO $validacao$
DECLARE
    falhas      text[] := '{}';
    avisos      text[] := '{}';
    ausentes    text;
    excedentes  text;
    item        text;
    n            bigint;
    n_aluno      bigint;
    n_turma      bigint;
    n_matricula  bigint;
    n_historico  bigint;
    n_vazias     bigint;

    -- As 16 tabelas do modelo lógico fornecido.
    tabelas_esperadas text[] := ARRAY[
        'tb_aluno','tb_campus','tb_curriculo','tb_curriculo_disciplina','tb_curso',
        'tb_disciplina','tb_feriado','tb_historico','tb_log_matricula','tb_matricula',
        'tb_periodo_letivo','tb_pre_requisito','tb_professor','tb_sala','tb_turma',
        'tb_turma_horario'];

    -- Os 18 relacionamentos (chaves estrangeiras) do modelo lógico, no formato
    -- "tabela.coluna -> tabela_referenciada".
    fks_esperadas text[] := ARRAY[
        'tb_curso.id_campus -> tb_campus',
        'tb_curriculo.id_curso -> tb_curso',
        'tb_curriculo_disciplina.id_curriculo -> tb_curriculo',
        'tb_curriculo_disciplina.id_disciplina -> tb_disciplina',
        'tb_pre_requisito.id_disciplina -> tb_disciplina',
        'tb_pre_requisito.id_requisito -> tb_disciplina',
        'tb_sala.id_campus -> tb_campus',
        'tb_feriado.id_campus -> tb_campus',
        'tb_turma.id_disciplina -> tb_disciplina',
        'tb_turma.id_periodo_letivo -> tb_periodo_letivo',
        'tb_turma.id_professor -> tb_professor',
        'tb_turma_horario.id_turma -> tb_turma',
        'tb_turma_horario.id_sala -> tb_sala',
        'tb_aluno.id_curso -> tb_curso',
        'tb_aluno.id_curriculo -> tb_curriculo',
        'tb_matricula.id_aluno -> tb_aluno',
        'tb_matricula.id_turma -> tb_turma',
        'tb_historico.id_matricula -> tb_matricula'];
BEGIN
    RAISE NOTICE '=== Validacao do Marco 1 ===';

    -- 1. Schema. Sem ele nada mais faz sentido, entao interrompe de imediato.
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata
                   WHERE schema_name = 'academico') THEN
        RAISE EXCEPTION 'Schema "academico" nao existe. Execute sql/01-create-tables.sql primeiro.';
    END IF;
    RAISE NOTICE '[OK]    schema academico existe';

    -- 2. As 16 tabelas esperadas, conferidas por NOME, nao apenas pela contagem.
    SELECT string_agg(t, ', ' ORDER BY t) INTO ausentes
    FROM unnest(tabelas_esperadas) t
    WHERE t NOT IN (SELECT tablename FROM pg_tables WHERE schemaname = 'academico');

    SELECT string_agg(tablename, ', ' ORDER BY tablename) INTO excedentes
    FROM pg_tables
    WHERE schemaname = 'academico' AND tablename <> ALL (tabelas_esperadas);

    IF ausentes IS NULL AND excedentes IS NULL THEN
        RAISE NOTICE '[OK]    16 tabelas do modelo presentes, nenhuma a mais';
    ELSE
        IF ausentes IS NOT NULL THEN
            falhas := falhas || format('tabelas ausentes: %s', ausentes);
        END IF;
        IF excedentes IS NOT NULL THEN
            falhas := falhas || format('tabelas fora do modelo: %s', excedentes);
        END IF;
    END IF;

    -- 3. Chave primaria em cada uma das tabelas do modelo.
    SELECT string_agg(t, ', ' ORDER BY t) INTO ausentes
    FROM unnest(tabelas_esperadas) t
    WHERE EXISTS (SELECT 1 FROM pg_tables
                  WHERE schemaname = 'academico' AND tablename = t)
      AND NOT EXISTS (
          SELECT 1 FROM pg_constraint c
          WHERE c.conrelid = ('academico.' || quote_ident(t))::regclass
            AND c.contype = 'p');
    IF ausentes IS NULL THEN
        RAISE NOTICE '[OK]    todas as tabelas tem chave primaria';
    ELSE
        falhas := falhas || format('tabelas sem chave primaria: %s', ausentes);
    END IF;

    -- 4. Os 18 relacionamentos do modelo, conferidos um a um pelo nome real
    -- das tabelas e colunas, e nao so pela contagem total.
    SELECT string_agg(f, ', ' ORDER BY f) INTO ausentes
    FROM unnest(fks_esperadas) f
    WHERE f NOT IN (
        SELECT format('%s.%s -> %s',
                      c.conrelid::regclass::text,
                      (SELECT string_agg(a.attname, ',' ORDER BY k.ord)
                         FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord)
                         JOIN pg_attribute a
                           ON a.attrelid = c.conrelid AND a.attnum = k.attnum),
                      c.confrelid::regclass::text)
        FROM pg_constraint c
        JOIN pg_namespace ns ON ns.oid = c.connamespace
        WHERE ns.nspname = 'academico' AND c.contype = 'f');

    SELECT count(*) INTO n
    FROM pg_constraint c
    JOIN pg_namespace ns ON ns.oid = c.connamespace
    WHERE ns.nspname = 'academico' AND c.contype = 'f';

    IF ausentes IS NULL AND n = 18 THEN
        RAISE NOTICE '[OK]    18 relacionamentos (FK) do modelo presentes';
    ELSE
        IF ausentes IS NOT NULL THEN
            falhas := falhas || format('relacionamentos ausentes: %s', ausentes);
        END IF;
        IF n <> 18 THEN
            falhas := falhas || format('esperadas 18 chaves estrangeiras, encontradas %s', n);
        END IF;
    END IF;

    -- 5. tb_log_matricula.id_matricula continua SEM FK, conforme o modelo fornecido.
    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'academico.tb_log_matricula'::regclass AND contype = 'f';
    IF n = 0 THEN
        RAISE NOTICE '[OK]    tb_log_matricula.id_matricula permanece sem FK (conforme o modelo)';
    ELSE
        falhas := falhas || 'tb_log_matricula ganhou FK; o modelo fornecido nao preve nenhuma'::text;
    END IF;

    -- 6. Colunas geradas.
    IF (SELECT is_generated FROM information_schema.columns
        WHERE table_schema = 'academico' AND table_name = 'tb_disciplina'
          AND column_name = 'ch_total') = 'ALWAYS' THEN
        RAISE NOTICE '[OK]    tb_disciplina.ch_total e coluna gerada';
    ELSE
        falhas := falhas || 'tb_disciplina.ch_total nao e coluna gerada'::text;
    END IF;

    IF (SELECT is_generated FROM information_schema.columns
        WHERE table_schema = 'academico' AND table_name = 'tb_historico'
          AND column_name = 'media_final') = 'ALWAYS' THEN
        RAISE NOTICE '[OK]    tb_historico.media_final e coluna gerada';
    ELSE
        falhas := falhas || 'tb_historico.media_final nao e coluna gerada'::text;
    END IF;

    -- 7. Minimos exigidos pelo enunciado do Marco 1.
    SELECT count(*) INTO n_aluno     FROM tb_aluno;
    SELECT count(*) INTO n_turma     FROM tb_turma;
    SELECT count(*) INTO n_matricula FROM tb_matricula;
    SELECT count(*) INTO n_historico FROM tb_historico;

    IF n_aluno >= 100 THEN
        RAISE NOTICE '[OK]    alunos: % (minimo 100)', n_aluno;
    ELSE
        falhas := falhas || format('alunos: %s, abaixo do minimo de 100', n_aluno);
    END IF;

    IF n_turma >= 6 THEN
        RAISE NOTICE '[OK]    turmas: % (minimo 6)', n_turma;
    ELSE
        falhas := falhas || format('turmas: %s, abaixo do minimo de 6', n_turma);
    END IF;

    IF n_matricula >= 300 THEN
        RAISE NOTICE '[OK]    matriculas: % (minimo 300)', n_matricula;
    ELSE
        falhas := falhas || format('matriculas: %s, abaixo do minimo de 300', n_matricula);
    END IF;

    -- 8. Carga atual esperada. Divergir nao viola o enunciado, entao entra
    -- como aviso, e nao como falha.
    IF (n_aluno, n_turma, n_matricula, n_historico)
       = (120::bigint, 10::bigint, 360::bigint, 360::bigint) THEN
        RAISE NOTICE '[OK]    carga atual confere: 120 alunos, 10 turmas, 360 matriculas, 360 historicos';
    ELSE
        avisos := avisos || format(
            'carga diferente da esperada (120/10/360/360): %s alunos, %s turmas, %s matriculas, %s historicos',
            n_aluno, n_turma, n_matricula, n_historico);
    END IF;

    -- 9. Pelo menos uma turma sem matriculas ativas, para a consulta 04 ter um
    -- caso real de juncao externa.
    SELECT count(*) INTO n_vazias FROM (
        SELECT t.id_turma
        FROM tb_turma t
        LEFT JOIN tb_matricula m ON m.id_turma = t.id_turma AND m.status = 'MATRICULADO'
        GROUP BY t.id_turma
        HAVING count(m.id_matricula) = 0) x;
    IF n_vazias >= 1 THEN
        RAISE NOTICE '[OK]    % turma(s) sem matriculas: a consulta 04 tem caso real de LEFT JOIN', n_vazias;
    ELSE
        falhas := falhas || 'nenhuma turma sem matriculas; a consulta 04 perde o caso de juncao externa'::text;
    END IF;

    -- Resumo final.
    IF array_length(avisos, 1) IS NOT NULL THEN
        RAISE NOTICE '---';
        FOREACH item IN ARRAY avisos LOOP
            RAISE NOTICE '[AVISO] %', item;
        END LOOP;
    END IF;

    IF array_length(falhas, 1) IS NOT NULL THEN
        RAISE EXCEPTION E'Validacao do Marco 1 FALHOU (% problema(s)):\n  - %',
            array_length(falhas, 1), array_to_string(falhas, E'\n  - ');
    END IF;

    RAISE NOTICE '---';
    RAISE NOTICE 'Validacao do Marco 1 concluida com sucesso.';
    RAISE NOTICE '16 tabelas, 18 relacionamentos, % alunos, % turmas, % matriculas, % historicos.',
        n_aluno, n_turma, n_matricula, n_historico;
END
$validacao$;

COMMIT;
