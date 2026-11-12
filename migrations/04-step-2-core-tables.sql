-- ====================================================================
-- FATEC SBC | IT Asset Management TCC | STEP 2A - CORE TABLES
-- MySQL 8.x | Intended for the EXISTING sistema_ti database
-- ====================================================================
-- PURPOSE: add asset maintenance and asset disposal history.
-- REQUIREMENTS: Step 1 is already applied (16 original tables).
-- SAFETY: does not DROP, DELETE or ALTER existing tables or rows.
--         Run on a local/test database first and back up your data.
-- NOTE: IF NOT EXISTS does NOT compare schemas if a table exists.
--       Run the verification queries and inspect results.
-- NOTE: MySQL DDL is implicitly committed; transaction rollback does
--       not undo CREATE TABLE.
-- ====================================================================

USE sistema_ti;

-- Each equipment may have multiple maintenance events.
CREATE TABLE IF NOT EXISTS manutencoes (
  id INT NOT NULL AUTO_INCREMENT,
  id_equipamento INT NOT NULL,
  id_usuario_registro INT NOT NULL,
  tipo VARCHAR(20) NOT NULL,
  descricao VARCHAR(500) NOT NULL,
  data_abertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_conclusao DATETIME NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ABERTA',
  custo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id),
  KEY idx_manutencoes_equipamento (id_equipamento),
  KEY idx_manutencoes_usuario (id_usuario_registro),
  KEY idx_manutencoes_status (status),
  CONSTRAINT fk_manutencoes_equipamento
    FOREIGN KEY (id_equipamento) REFERENCES equipamentos(id),
  CONSTRAINT fk_manutencoes_usuario
    FOREIGN KEY (id_usuario_registro) REFERENCES usuarios(id),
  CONSTRAINT chk_manutencoes_tipo
    CHECK (tipo IN ('PREVENTIVA', 'CORRETIVA')),
  CONSTRAINT chk_manutencoes_status
    CHECK (status IN ('ABERTA', 'EM_ANDAMENTO', 'CONCLUIDA')),
  CONSTRAINT chk_manutencoes_custo
    CHECK (custo >= 0),
  CONSTRAINT chk_manutencoes_datas
    CHECK (data_conclusao IS NULL OR data_conclusao >= data_abertura)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Each individual asset has at most one final disposal record.
CREATE TABLE IF NOT EXISTS descartes (
  id INT NOT NULL AUTO_INCREMENT,
  id_equipamento INT NOT NULL,
  id_usuario_responsavel INT NOT NULL,
  data_descarte DATE NOT NULL,
  tipo_destinacao VARCHAR(20) NOT NULL,
  motivo VARCHAR(255) NOT NULL,
  observacoes VARCHAR(500) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_descartes_equipamento (id_equipamento),
  KEY idx_descartes_usuario (id_usuario_responsavel),
  CONSTRAINT fk_descartes_equipamento
    FOREIGN KEY (id_equipamento) REFERENCES equipamentos(id),
  CONSTRAINT fk_descartes_usuario
    FOREIGN KEY (id_usuario_responsavel) REFERENCES usuarios(id),
  CONSTRAINT chk_descartes_tipo
    CHECK (tipo_destinacao IN ('RECICLAGEM', 'DOACAO', 'VENDA', 'OUTRO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Verify both tables exist in the current schema.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('manutencoes', 'descartes')
ORDER BY table_name;

-- Review constraints and column definitions in DBeaver if needed:
SHOW CREATE TABLE manutencoes;
SHOW CREATE TABLE descartes;

-- Business-rule reminder for the Spring Boot service:
-- In one @Transactional operation, insert a disposal event AND set
-- equipamentos.status='Descartado'. Do not delete asset history.
