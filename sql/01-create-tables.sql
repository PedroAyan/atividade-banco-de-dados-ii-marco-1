-- Marco 1 — Sistema de Matrícula Acadêmica — Banco de Dados II, 2026/2
-- DDL adaptado do modelo lógico e do 01_modelo.sql fornecidos pelo professor.
-- Alvo: PostgreSQL 17 (docker-compose.yml do projeto).
-- Executar uma vez em banco novo, com permissão para instalar btree_gist.
-- Não apaga nem recria um schema existente. Erro desfaz a transação inteira.
-- Este arquivo contém estrutura e integridade declarativa; não contém carga,
-- consultas, views, segurança, auditoria automática ou controle da última vaga.

BEGIN;

CREATE SCHEMA academico;
SET search_path TO academico, public;

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------------
-- 1. TIPOS E DOMÍNIOS
-- ---------------------------------------------------------------------
CREATE TYPE turno_t       AS ENUM ('MATUTINO','VESPERTINO','NOTURNO');
CREATE TYPE tipo_disc_t   AS ENUM ('OBRIGATORIA','OPTATIVA');
CREATE TYPE vinculo_t     AS ENUM ('PRE_REQUISITO','CO_REQUISITO');
CREATE TYPE status_mat_t  AS ENUM ('MATRICULADO','TRANCADO','CANCELADO');
CREATE TYPE situacao_t    AS ENUM ('CURSANDO','APROVADO','REPROVADO_NOTA','REPROVADO_FALTA');
CREATE TYPE tipo_sala_t   AS ENUM ('TEORICA','LABORATORIO');

CREATE DOMAIN nota_t AS numeric(4,2) CHECK (VALUE >= 0 AND VALUE <= 10);
CREATE DOMAIN pct_t  AS numeric(5,2) CHECK (VALUE >= 0 AND VALUE <= 100);

-- faixa de horário: exercita tipos de intervalo e restrições EXCLUDE
CREATE TYPE timerange AS RANGE (subtype = time);

-- ---------------------------------------------------------------------
-- 2. ESTRUTURA INSTITUCIONAL
-- ---------------------------------------------------------------------
CREATE TABLE tb_campus (
    id_campus smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_campus    varchar(60) NOT NULL UNIQUE,
    cidade_campus  varchar(60) NOT NULL
);

CREATE TABLE tb_curso (
    id_curso smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_curso     varchar(10) NOT NULL UNIQUE,
    nome_curso       varchar(120) NOT NULL,
    grau_curso       varchar(20) NOT NULL
               CHECK (grau_curso IN ('BACHARELADO','LICENCIATURA','TECNOLOGO')),
    ch_total_curso   integer NOT NULL CHECK (ch_total_curso > 0),
    id_campus  smallint NOT NULL REFERENCES tb_campus (id_campus) ON DELETE RESTRICT
);

CREATE TABLE tb_curriculo (
    id_curriculo integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_curso      smallint NOT NULL REFERENCES tb_curso (id_curso) ON DELETE CASCADE,
    ano_vigencia_curriculo  smallint NOT NULL CHECK (ano_vigencia_curriculo BETWEEN 2000 AND 2100),
    ativo_curriculo         boolean  NOT NULL DEFAULT false,
    UNIQUE (id_curso, ano_vigencia_curriculo)
);
-- regra: no máximo um currículo ativo por curso (índice único parcial)
CREATE UNIQUE INDEX uq_curriculo_ativo
    ON tb_curriculo (id_curso) WHERE ativo_curriculo;

CREATE TABLE tb_disciplina (
    id_disciplina integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_disciplina       varchar(10) NOT NULL UNIQUE,
    nome_disciplina         varchar(120) NOT NULL,
    ch_teorica_disciplina   smallint NOT NULL CHECK (ch_teorica_disciplina >= 0),
    ch_pratica_disciplina   smallint NOT NULL CHECK (ch_pratica_disciplina >= 0),
    ch_total_disciplina     smallint GENERATED ALWAYS AS (ch_teorica_disciplina + ch_pratica_disciplina) STORED,
    ementa_disciplina       text,
    CHECK (ch_teorica_disciplina + ch_pratica_disciplina > 0)
);

CREATE TABLE tb_curriculo_disciplina (
    id_curriculo  integer NOT NULL REFERENCES tb_curriculo (id_curriculo) ON DELETE CASCADE,
    id_disciplina integer NOT NULL REFERENCES tb_disciplina (id_disciplina) ON DELETE RESTRICT,
    periodo_curriculo_disciplina       smallint NOT NULL CHECK (periodo_curriculo_disciplina BETWEEN 1 AND 12),
    tipo_curriculo_disciplina          tipo_disc_t NOT NULL DEFAULT 'OBRIGATORIA',
    PRIMARY KEY (id_curriculo, id_disciplina)
);

-- Associação entre duas disciplinas, usada nas consultas recursivas.
-- O CHECK abaixo impede autorreferência direta; não detecta ciclos indiretos.
CREATE TABLE tb_pre_requisito (
    id_disciplina integer NOT NULL REFERENCES tb_disciplina (id_disciplina) ON DELETE CASCADE,
    id_requisito  integer NOT NULL REFERENCES tb_disciplina (id_disciplina) ON DELETE RESTRICT,
    vinculo_pre_requisito       vinculo_t NOT NULL DEFAULT 'PRE_REQUISITO',
    PRIMARY KEY (id_disciplina, id_requisito),
    CHECK (id_disciplina <> id_requisito)
);

CREATE TABLE tb_professor (
    id_professor integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula_professor  varchar(12) NOT NULL UNIQUE,
    nome_professor       varchar(120) NOT NULL,
    email_professor      varchar(120) NOT NULL UNIQUE
               CHECK (email_professor ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$'),
    titulacao_professor  varchar(20) NOT NULL
               CHECK (titulacao_professor IN ('ESPECIALISTA','MESTRE','DOUTOR'))
);

CREATE TABLE tb_sala (
    id_sala   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_campus   smallint NOT NULL REFERENCES tb_campus (id_campus) ON DELETE RESTRICT,
    codigo_sala      varchar(10) NOT NULL,
    capacidade_sala  smallint NOT NULL CHECK (capacidade_sala > 0),
    tipo_sala        tipo_sala_t NOT NULL DEFAULT 'TEORICA',
    UNIQUE (id_campus, codigo_sala)
);

-- ---------------------------------------------------------------------
-- 3. OFERTA
-- ---------------------------------------------------------------------
CREATE TABLE tb_periodo_letivo (
    id_periodo_letivo smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ano_periodo_letivo          smallint NOT NULL,
    semestre_periodo_letivo     smallint NOT NULL CHECK (semestre_periodo_letivo IN (1,2)),
    data_inicio_periodo_letivo  date NOT NULL,
    data_fim_periodo_letivo     date NOT NULL,
    UNIQUE (ano_periodo_letivo, semestre_periodo_letivo),
    CHECK (data_fim_periodo_letivo > data_inicio_periodo_letivo)
);

CREATE TABLE tb_feriado (
    id_feriado integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data_feriado       date NOT NULL,
    descricao_feriado  varchar(120) NOT NULL,
    id_campus  smallint REFERENCES tb_campus (id_campus) ON DELETE CASCADE,  -- NULL = todos
    UNIQUE (data_feriado, id_campus)
);

CREATE TABLE tb_turma (
    id_turma         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_turma             varchar(15) NOT NULL,
    id_disciplina      integer  NOT NULL REFERENCES tb_disciplina (id_disciplina) ON DELETE RESTRICT,
    id_periodo_letivo  smallint NOT NULL REFERENCES tb_periodo_letivo (id_periodo_letivo) ON DELETE RESTRICT,
    id_professor       integer  REFERENCES tb_professor (id_professor) ON DELETE SET NULL,
    turno_turma              turno_t  NOT NULL,
    vagas_turma              smallint NOT NULL CHECK (vagas_turma > 0),
    UNIQUE (codigo_turma, id_periodo_letivo, id_disciplina)
);

CREATE TABLE tb_turma_horario (
    id_turma_horario integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_turma    integer NOT NULL REFERENCES tb_turma (id_turma) ON DELETE CASCADE,
    id_sala     integer NOT NULL REFERENCES tb_sala (id_sala) ON DELETE RESTRICT,
    dia_semana_turma_horario  smallint NOT NULL CHECK (dia_semana_turma_horario BETWEEN 1 AND 7), -- 1=domingo
    faixa_turma_horario       timerange NOT NULL,
    CHECK (NOT isempty(faixa_turma_horario))
);

-- Restrição conforme o SQL de referência do professor.
-- Atenção: o escopo é global, sem distinguir períodos letivos.
-- Reutilizar a mesma sala/horário em semestres diferentes exige rever esta regra.
-- Uma sala não pode receber duas turmas no mesmo dia e horário
ALTER TABLE tb_turma_horario
    ADD CONSTRAINT ex_sala_ocupada
    EXCLUDE USING gist (id_sala WITH =, dia_semana_turma_horario WITH =, faixa_turma_horario WITH &&);

-- ---------------------------------------------------------------------
-- 4. VIDA ACADÊMICA
-- ---------------------------------------------------------------------
CREATE TABLE tb_aluno (
    id_aluno    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula_aluno     varchar(12) NOT NULL UNIQUE,
    nome_aluno          varchar(120) NOT NULL,
    cpf_aluno           char(11) NOT NULL UNIQUE CHECK (cpf_aluno ~ '^[0-9]{11}$'),
    email_aluno         varchar(120) NOT NULL UNIQUE,
    nascimento_aluno    date NOT NULL CHECK (nascimento_aluno < CURRENT_DATE),
    id_curso      smallint NOT NULL REFERENCES tb_curso (id_curso) ON DELETE RESTRICT,
    id_curriculo  integer  NOT NULL REFERENCES tb_curriculo (id_curriculo) ON DELETE RESTRICT,
    ingresso_aluno      date NOT NULL,
    ativo_aluno         boolean NOT NULL DEFAULT true
);

CREATE TABLE tb_matricula (
    id_matricula  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_aluno        integer NOT NULL REFERENCES tb_aluno (id_aluno) ON DELETE CASCADE,
    id_turma        integer NOT NULL REFERENCES tb_turma (id_turma) ON DELETE RESTRICT,
    data_matricula  timestamptz NOT NULL DEFAULT now(),
    status_matricula          status_mat_t NOT NULL DEFAULT 'MATRICULADO',
    UNIQUE (id_aluno, id_turma)
);

CREATE TABLE tb_historico (
    id_historico integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_matricula  integer NOT NULL UNIQUE REFERENCES tb_matricula (id_matricula) ON DELETE CASCADE,
    nota_a1_historico       nota_t,
    nota_a2_historico       nota_t,
    nota_p3_historico       nota_t,
    frequencia_historico    pct_t NOT NULL DEFAULT 100,
    situacao_historico      situacao_t NOT NULL DEFAULT 'CURSANDO',
    -- Fórmula reproduzida do SQL de referência: com P3, usa o maior
    -- resultado entre as duas possibilidades de substituição.
    media_final_historico numeric(4,2) GENERATED ALWAYS AS (
        CASE
          WHEN nota_a1_historico IS NULL OR nota_a2_historico IS NULL THEN NULL
          WHEN nota_p3_historico IS NULL THEN round(0.4*nota_a1_historico + 0.6*nota_a2_historico, 2)
          ELSE round(greatest(0.4*nota_p3_historico + 0.6*nota_a2_historico,
                              0.4*nota_a1_historico + 0.6*nota_p3_historico), 2)
        END
    ) STORED
);

-- Auditoria: id_matricula não tem FK no modelo fornecido.
-- A criação desta tabela não gera registros de auditoria automaticamente.
CREATE TABLE tb_log_matricula (
    id_log_matricula bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_matricula  integer NOT NULL,
    acao_log_matricula          varchar(20) NOT NULL,
    ocorrido_em_log_matricula   timestamptz NOT NULL DEFAULT now(),
    usuario_log_matricula       name NOT NULL DEFAULT CURRENT_USER,
    detalhe_log_matricula       jsonb
);

COMMIT;
