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
CREATE TABLE campus (
    id      smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome    varchar(60) NOT NULL UNIQUE,
    cidade  varchar(60) NOT NULL
);

CREATE TABLE curso (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo     varchar(10) NOT NULL UNIQUE,
    nome       varchar(120) NOT NULL,
    grau       varchar(20) NOT NULL
               CHECK (grau IN ('BACHARELADO','LICENCIATURA','TECNOLOGO')),
    ch_total   integer NOT NULL CHECK (ch_total > 0),
    campus_id  smallint NOT NULL REFERENCES campus ON DELETE RESTRICT
);

CREATE TABLE curriculo (
    id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    curso_id      smallint NOT NULL REFERENCES curso ON DELETE CASCADE,
    ano_vigencia  smallint NOT NULL CHECK (ano_vigencia BETWEEN 2000 AND 2100),
    ativo         boolean  NOT NULL DEFAULT false,
    UNIQUE (curso_id, ano_vigencia)
);
-- regra: no máximo um currículo ativo por curso (índice único parcial)
CREATE UNIQUE INDEX uq_curriculo_ativo
    ON curriculo (curso_id) WHERE ativo;

CREATE TABLE disciplina (
    id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       varchar(10) NOT NULL UNIQUE,
    nome         varchar(120) NOT NULL,
    ch_teorica   smallint NOT NULL CHECK (ch_teorica >= 0),
    ch_pratica   smallint NOT NULL CHECK (ch_pratica >= 0),
    ch_total     smallint GENERATED ALWAYS AS (ch_teorica + ch_pratica) STORED,
    ementa       text,
    CHECK (ch_teorica + ch_pratica > 0)
);

CREATE TABLE curriculo_disciplina (
    curriculo_id  integer NOT NULL REFERENCES curriculo ON DELETE CASCADE,
    disciplina_id integer NOT NULL REFERENCES disciplina ON DELETE RESTRICT,
    periodo       smallint NOT NULL CHECK (periodo BETWEEN 1 AND 12),
    tipo          tipo_disc_t NOT NULL DEFAULT 'OBRIGATORIA',
    PRIMARY KEY (curriculo_id, disciplina_id)
);

-- Associação entre duas disciplinas, usada nas consultas recursivas.
-- O CHECK abaixo impede autorreferência direta; não detecta ciclos indiretos.
CREATE TABLE pre_requisito (
    disciplina_id integer NOT NULL REFERENCES disciplina ON DELETE CASCADE,
    requisito_id  integer NOT NULL REFERENCES disciplina ON DELETE RESTRICT,
    vinculo       vinculo_t NOT NULL DEFAULT 'PRE_REQUISITO',
    PRIMARY KEY (disciplina_id, requisito_id),
    CHECK (disciplina_id <> requisito_id)
);

CREATE TABLE professor (
    id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula  varchar(12) NOT NULL UNIQUE,
    nome       varchar(120) NOT NULL,
    email      varchar(120) NOT NULL UNIQUE
               CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$'),
    titulacao  varchar(20) NOT NULL
               CHECK (titulacao IN ('ESPECIALISTA','MESTRE','DOUTOR'))
);

CREATE TABLE sala (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    campus_id   smallint NOT NULL REFERENCES campus ON DELETE RESTRICT,
    codigo      varchar(10) NOT NULL,
    capacidade  smallint NOT NULL CHECK (capacidade > 0),
    tipo        tipo_sala_t NOT NULL DEFAULT 'TEORICA',
    UNIQUE (campus_id, codigo)
);

-- ---------------------------------------------------------------------
-- 3. OFERTA
-- ---------------------------------------------------------------------
CREATE TABLE periodo_letivo (
    id           smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ano          smallint NOT NULL,
    semestre     smallint NOT NULL CHECK (semestre IN (1,2)),
    data_inicio  date NOT NULL,
    data_fim     date NOT NULL,
    UNIQUE (ano, semestre),
    CHECK (data_fim > data_inicio)
);

CREATE TABLE feriado (
    id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data       date NOT NULL,
    descricao  varchar(120) NOT NULL,
    campus_id  smallint REFERENCES campus ON DELETE CASCADE,  -- NULL = todos
    UNIQUE (data, campus_id)
);

CREATE TABLE turma (
    id                 integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo             varchar(15) NOT NULL,
    disciplina_id      integer  NOT NULL REFERENCES disciplina ON DELETE RESTRICT,
    periodo_letivo_id  smallint NOT NULL REFERENCES periodo_letivo ON DELETE RESTRICT,
    professor_id       integer  REFERENCES professor ON DELETE SET NULL,
    turno              turno_t  NOT NULL,
    vagas              smallint NOT NULL CHECK (vagas > 0),
    UNIQUE (codigo, periodo_letivo_id, disciplina_id)
);

CREATE TABLE turma_horario (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    turma_id    integer NOT NULL REFERENCES turma ON DELETE CASCADE,
    sala_id     integer NOT NULL REFERENCES sala ON DELETE RESTRICT,
    dia_semana  smallint NOT NULL CHECK (dia_semana BETWEEN 1 AND 7), -- 1=domingo
    faixa       timerange NOT NULL,
    CHECK (NOT isempty(faixa))
);

-- Restrição conforme o SQL de referência do professor.
-- Atenção: o escopo é global, sem distinguir períodos letivos.
-- Reutilizar a mesma sala/horário em semestres diferentes exige rever esta regra.
-- Uma sala não pode receber duas turmas no mesmo dia e horário
ALTER TABLE turma_horario
    ADD CONSTRAINT ex_sala_ocupada
    EXCLUDE USING gist (sala_id WITH =, dia_semana WITH =, faixa WITH &&);

-- ---------------------------------------------------------------------
-- 4. VIDA ACADÊMICA
-- ---------------------------------------------------------------------
CREATE TABLE aluno (
    id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula     varchar(12) NOT NULL UNIQUE,
    nome          varchar(120) NOT NULL,
    cpf           char(11) NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    email         varchar(120) NOT NULL UNIQUE,
    nascimento    date NOT NULL CHECK (nascimento < CURRENT_DATE),
    curso_id      smallint NOT NULL REFERENCES curso ON DELETE RESTRICT,
    curriculo_id  integer  NOT NULL REFERENCES curriculo ON DELETE RESTRICT,
    ingresso      date NOT NULL,
    ativo         boolean NOT NULL DEFAULT true
);

CREATE TABLE matricula (
    id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    aluno_id        integer NOT NULL REFERENCES aluno  ON DELETE CASCADE,
    turma_id        integer NOT NULL REFERENCES turma  ON DELETE RESTRICT,
    data_matricula  timestamptz NOT NULL DEFAULT now(),
    status          status_mat_t NOT NULL DEFAULT 'MATRICULADO',
    UNIQUE (aluno_id, turma_id)
);

CREATE TABLE historico (
    id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula_id  integer NOT NULL UNIQUE REFERENCES matricula ON DELETE CASCADE,
    nota_a1       nota_t,
    nota_a2       nota_t,
    nota_p3       nota_t,
    frequencia    pct_t NOT NULL DEFAULT 100,
    situacao      situacao_t NOT NULL DEFAULT 'CURSANDO',
    -- Fórmula reproduzida do SQL de referência: com P3, usa o maior
    -- resultado entre as duas possibilidades de substituição.
    media_final numeric(4,2) GENERATED ALWAYS AS (
        CASE
          WHEN nota_a1 IS NULL OR nota_a2 IS NULL THEN NULL
          WHEN nota_p3 IS NULL THEN round(0.4*nota_a1 + 0.6*nota_a2, 2)
          ELSE round(greatest(0.4*nota_p3 + 0.6*nota_a2,
                              0.4*nota_a1 + 0.6*nota_p3), 2)
        END
    ) STORED
);

-- Auditoria: matricula_id não tem FK no modelo fornecido.
-- A criação desta tabela não gera registros de auditoria automaticamente.
CREATE TABLE log_matricula (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula_id  integer NOT NULL,
    acao          varchar(20) NOT NULL,
    ocorrido_em   timestamptz NOT NULL DEFAULT now(),
    usuario       name NOT NULL DEFAULT CURRENT_USER,
    detalhe       jsonb
);

COMMIT;
