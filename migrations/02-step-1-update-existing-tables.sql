-- =============================================================
-- FATEC SBC | TCC - IT Asset Management
-- STEP 1: Update the 16 EXISTING database tables
-- Compatible with the supplied MySQL 8.0.46 schema.
-- Does not create, drop, or delete any table or record.
-- =============================================================
-- HOW TO USE
-- 1. Back up the database.
-- 2. Run the duplicate-check SELECT queries below separately.
--    They should return NO ROWS. If rows appear, resolve them
--    before running the ALTER TABLE statements.
-- 3. Run this script ONCE on your TEST database first.
-- 4. Verify the results and only then apply to a shared database.
-- WARNING: MySQL DDL commits implicitly; do not expect rollback.
-- WARNING: Existing database must match Rafael's supplied dump.
-- =============================================================

USE sistema_ti;

-- PRE-CHECK A: Any duplicate role names? Must return zero rows.
SELECT nome, COUNT(*) AS occurrences
FROM roles
GROUP BY nome
HAVING COUNT(*) > 1;

-- PRE-CHECK B: Any duplicated user/role assignments? Zero rows.
SELECT id_usuario, id_role, COUNT(*) AS occurrences
FROM usuarios_roles
GROUP BY id_usuario, id_role
HAVING COUNT(*) > 1;

-- STOP HERE and review both results before running the ALTERs.
-- This SELECT section does not automatically stop execution.

-- 1) One equipamentos.id = one physical asset.
ALTER TABLE equipamentos
  ADD COLUMN numero_serie VARCHAR(100) NULL,
  ADD COLUMN condicao VARCHAR(30) NOT NULL DEFAULT 'BOM',
  ADD COLUMN id_localizacao_atual INT NULL,
  ADD COLUMN id_usuario_responsavel INT NULL,
  ADD COLUMN data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD UNIQUE KEY uq_equipamentos_numero_serie (numero_serie),
  ADD KEY idx_equipamentos_localizacao (id_localizacao_atual),
  ADD KEY idx_equipamentos_responsavel (id_usuario_responsavel),
  ADD KEY idx_equipamentos_status (status),
  ADD CONSTRAINT fk_equipamentos_localizacao_atual
    FOREIGN KEY (id_localizacao_atual) REFERENCES localizacao(id),
  ADD CONSTRAINT fk_equipamentos_usuario_responsavel
    FOREIGN KEY (id_usuario_responsavel) REFERENCES usuarios(id),
  ADD CONSTRAINT chk_equipamentos_condicao
    CHECK (condicao IN ('BOM', 'REGULAR', 'RUIM', 'INUTILIZAVEL'));

-- Keep Rafael's original status column (default 'Ativo').
-- Suggested business values (enforce in Spring Boot):
-- 'Ativo', 'Em manutencao', 'Bloqueado', 'Descartado'.
-- status='Ativo' + NULL responsible user indicates availability.
-- Leave estoque_min unchanged, but out of the one-asset MVP.

-- 2) Computers and servers share hardware specifications.
ALTER TABLE especificacoes_computador
  ADD COLUMN hostname VARCHAR(150) NULL,
  MODIFY COLUMN endereco_ip VARCHAR(45) NULL;

-- 3) Transfer history: operator, destination, date and prior state.
-- Existing movimentacao.id_localizacao means DESTINATION.
-- Existing movimentacao.id_usuario means the recording USER.
ALTER TABLE movimentacao
  ADD COLUMN data_movimentacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN id_localizacao_origem INT NULL,
  ADD COLUMN id_responsavel_anterior INT NULL,
  ADD COLUMN id_responsavel_novo INT NULL,
  ADD KEY idx_movimentacao_data (data_movimentacao),
  ADD KEY idx_movimentacao_origem (id_localizacao_origem),
  ADD KEY idx_movimentacao_responsavel_anterior (id_responsavel_anterior),
  ADD KEY idx_movimentacao_responsavel_novo (id_responsavel_novo),
  ADD CONSTRAINT fk_movimentacao_localizacao_origem
    FOREIGN KEY (id_localizacao_origem) REFERENCES localizacao(id),
  ADD CONSTRAINT fk_movimentacao_responsavel_anterior
    FOREIGN KEY (id_responsavel_anterior) REFERENCES usuarios(id),
  ADD CONSTRAINT fk_movimentacao_responsavel_novo
    FOREIGN KEY (id_responsavel_novo) REFERENCES usuarios(id);

-- 4) Record who blocked the equipment.
ALTER TABLE bloqueio_equipamento
  ADD COLUMN id_usuario_registro INT NULL,
  ADD KEY idx_bloqueio_usuario_registro (id_usuario_registro),
  ADD CONSTRAINT fk_bloqueio_usuario_registro
    FOREIGN KEY (id_usuario_registro) REFERENCES usuarios(id);

-- 5) One simplified license pool per software product.
-- NULL = untracked/not applicable (e.g. open-source software).
-- Multiple contracts per software would need an additional
-- license table, outside this MVP.
ALTER TABLE softwares
  ADD COLUMN quantidade_licencas INT NULL,
  ADD CONSTRAINT chk_softwares_quantidade_licencas
    CHECK (quantidade_licencas IS NULL OR quantidade_licencas >= 0);

ALTER TABLE instalacoes_software
  ADD COLUMN data_desinstalacao DATETIME NULL;
-- Validate duplicate active installs in the API.
-- Do not store software activation keys in plaintext.

-- 6) Users can be deactivated without deleting their history.
ALTER TABLE usuarios
  ADD COLUMN ativo TINYINT(1) NOT NULL DEFAULT 1,
  ADD CONSTRAINT chk_usuarios_ativo CHECK (ativo IN (0, 1));
-- Existing usuarios.senha must store only a secure password hash
-- produced by the application (e.g., bcrypt/Argon2id).

-- Prevent duplicated roles or user/role assignments.
ALTER TABLE roles
  ADD UNIQUE KEY uq_roles_nome (nome);
ALTER TABLE usuarios_roles
  ADD UNIQUE KEY uq_usuarios_roles_par (id_usuario, id_role);

-- BASIC VERIFICATION (review the structure manually):
SHOW COLUMNS FROM equipamentos;
SHOW COLUMNS FROM movimentacao;
SHOW COLUMNS FROM especificacoes_computador;
SHOW COLUMNS FROM softwares;
SHOW COLUMNS FROM usuarios;
SHOW INDEX FROM roles;
SHOW INDEX FROM usuarios_roles;

-- Before proceeding to STEP 2, agree on business rules:
-- one equipamentos row represents ONE unique physical asset.
-- The original estoque/estoque_min remain unchanged for now.
