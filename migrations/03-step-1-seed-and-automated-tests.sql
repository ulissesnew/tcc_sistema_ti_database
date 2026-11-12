-- =====================================================================
-- FATEC SBC | TCC - IT Asset Management
-- STEP 1 - SAMPLE DATA + AUTOMATED SMOKE TESTS (MySQL 8.0)
-- =====================================================================
-- PURPOSE
--   1. Insert a small, realistic test data set into the EXISTING 16 tables.
--   2. Simulate purchasing, assigning, transferring and blocking laptops.
--   3. Test new STEP 1 columns, foreign keys, indexes and simple queries.
--   4. Return PASS/FAIL results in a single DBeaver result grid.
--
-- REQUIREMENTS
--   - Database 'sistema_ti' already exists.
--   - TCC_Step_1_Update_Existing_Tables.sql has already been applied.
--   - Step 2 is NOT required (no new permanent tables are created).
--
-- SAFETY
--   - USE ONLY ON A LOCAL/TEST DATABASE (take a backup first).
--   - Inserts only identifiable TCC_TEST_* rows; no DROP/DELETE/TRUNCATE.
--   - Safe to run again: existing test records are reused instead of
--     inserting duplicate movements, users, assets or installations.
--   - The script intentionally updates ONLY its own sample equipment
--     to reflect the transfer and blocked-device scenarios.
--   - COMMIT saves test rows so you can inspect them later in DBeaver.
--   - If DBeaver encounters an error, STOP execution and ROLLBACK the
--     transaction before investigating; do not continue past an error.
--   - Seeded account passwords are INVALID placeholders, not credentials.
--     These users are for database tests, NOT for signing in to the app.
-- =====================================================================

USE sistema_ti;
START TRANSACTION;

-- =====================================================================
-- A. USERS, ROLES, DEPARTMENT, LOCATIONS
-- =====================================================================
INSERT INTO setor (nome_setor, status)
SELECT 'TCC_TEST_TI', 1
WHERE NOT EXISTS (SELECT 1 FROM setor WHERE nome_setor = 'TCC_TEST_TI');
SET @test_setor := (SELECT id FROM setor WHERE nome_setor = 'TCC_TEST_TI' ORDER BY id LIMIT 1);

INSERT INTO roles (nome, status)
SELECT 'TCC_TEST_ADMIN', 1
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE nome = 'TCC_TEST_ADMIN');
INSERT INTO roles (nome, status)
SELECT 'TCC_TEST_USER', 1
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE nome = 'TCC_TEST_USER');
SET @role_admin := (SELECT id FROM roles WHERE nome = 'TCC_TEST_ADMIN' ORDER BY id LIMIT 1);
SET @role_user  := (SELECT id FROM roles WHERE nome = 'TCC_TEST_USER' ORDER BY id LIMIT 1);

-- Deliberately NON-AUTHENTICATABLE 'senha' values: database testing only.
INSERT INTO usuarios (nome, email, senha, cargo, id_setor, ativo)
SELECT 'TCC Test Operator', 'tcc.test.operator@example.invalid',
       '!TCC_TEST_NOT_A_VALID_PASSWORD_HASH!', 'IT Administrator', @test_setor, 1
WHERE NOT EXISTS (SELECT 1 FROM usuarios WHERE email = 'tcc.test.operator@example.invalid');

INSERT INTO usuarios (nome, email, senha, cargo, id_setor, ativo)
SELECT 'TCC Test Employee A', 'tcc.test.employee.a@example.invalid',
       '!TCC_TEST_NOT_A_VALID_PASSWORD_HASH!', 'Analyst', @test_setor, 1
WHERE NOT EXISTS (SELECT 1 FROM usuarios WHERE email = 'tcc.test.employee.a@example.invalid');

INSERT INTO usuarios (nome, email, senha, cargo, id_setor, ativo)
SELECT 'TCC Test Employee B', 'tcc.test.employee.b@example.invalid',
       '!TCC_TEST_NOT_A_VALID_PASSWORD_HASH!', 'Analyst', @test_setor, 1
WHERE NOT EXISTS (SELECT 1 FROM usuarios WHERE email = 'tcc.test.employee.b@example.invalid');

INSERT INTO usuarios (nome, email, senha, cargo, id_setor, ativo)
SELECT 'TCC Test Inactive User', 'tcc.test.inactive@example.invalid',
       '!TCC_TEST_NOT_A_VALID_PASSWORD_HASH!', 'Former Intern', @test_setor, 0
WHERE NOT EXISTS (SELECT 1 FROM usuarios WHERE email = 'tcc.test.inactive@example.invalid');

SET @operator := (SELECT id FROM usuarios WHERE email = 'tcc.test.operator@example.invalid');
SET @owner_a  := (SELECT id FROM usuarios WHERE email = 'tcc.test.employee.a@example.invalid');
SET @owner_b  := (SELECT id FROM usuarios WHERE email = 'tcc.test.employee.b@example.invalid');
SET @inactive := (SELECT id FROM usuarios WHERE email = 'tcc.test.inactive@example.invalid');

INSERT INTO usuarios_roles (id_usuario, id_role)
SELECT @operator, @role_admin
WHERE NOT EXISTS (SELECT 1 FROM usuarios_roles WHERE id_usuario = @operator AND id_role = @role_admin);
INSERT INTO usuarios_roles (id_usuario, id_role)
SELECT @owner_a, @role_user
WHERE NOT EXISTS (SELECT 1 FROM usuarios_roles WHERE id_usuario = @owner_a AND id_role = @role_user);
INSERT INTO usuarios_roles (id_usuario, id_role)
SELECT @owner_b, @role_user
WHERE NOT EXISTS (SELECT 1 FROM usuarios_roles WHERE id_usuario = @owner_b AND id_role = @role_user);

INSERT INTO localizacao (nome_local, descricao)
SELECT 'TCC_TEST_Storage', 'TCC test equipment storage'
WHERE NOT EXISTS (SELECT 1 FROM localizacao WHERE nome_local = 'TCC_TEST_Storage');
INSERT INTO localizacao (nome_local, descricao)
SELECT 'TCC_TEST_IT_Lab', 'TCC test IT laboratory'
WHERE NOT EXISTS (SELECT 1 FROM localizacao WHERE nome_local = 'TCC_TEST_IT_Lab');
SET @location_a := (SELECT id FROM localizacao WHERE nome_local = 'TCC_TEST_Storage' ORDER BY id LIMIT 1);
SET @location_b := (SELECT id FROM localizacao WHERE nome_local = 'TCC_TEST_IT_Lab' ORDER BY id LIMIT 1);

-- =====================================================================
-- B. SUPPLIER, PURCHASE AND TWO SEPARATE PHYSICAL LAPTOPS
-- =====================================================================
-- The CNPJ below is fictitious and exists only for database demonstrations.
INSERT INTO fornecedor (razao_social, nome_fan, cnpj, uf, endereco)
SELECT 'TCC_TEST Supplier (fictional)', 'TCC_TEST Supplier',
       '00.000.000/0000-00', 'SP', 'Synthetic test address - Fatec SBC'
WHERE NOT EXISTS (SELECT 1 FROM fornecedor WHERE cnpj = '00.000.000/0000-00');
SET @supplier := (SELECT id FROM fornecedor WHERE cnpj = '00.000.000/0000-00');

INSERT INTO compra (data_compra, valor_compra, id_fornecedor, cod_pedido, num_nota)
SELECT CURDATE(), 9000.00, @supplier, 'TCC_TEST_ORDER_001', 'TCC_TEST_NF_001'
WHERE NOT EXISTS (SELECT 1 FROM compra WHERE cod_pedido = 'TCC_TEST_ORDER_001');
SET @purchase := (SELECT id FROM compra WHERE cod_pedido = 'TCC_TEST_ORDER_001' ORDER BY id LIMIT 1);

-- Both devices are separate rows, even though they share brand and model.
INSERT INTO equipamentos
  (nome, tipo, patrimonio, marca, modelo, status, data_garantia,
   vida_util_estimada_meses, numero_serie, condicao,
   id_localizacao_atual, id_usuario_responsavel)
SELECT 'TCC Test Laptop A', 'Notebook', 'TCC_TEST_PAT_001', 'Dell', 'Latitude Test',
       'Ativo', DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 48,
       'TCC_TEST_SN_001', 'BOM', @location_a, @owner_a
WHERE NOT EXISTS (SELECT 1 FROM equipamentos WHERE patrimonio = 'TCC_TEST_PAT_001');

INSERT INTO equipamentos
  (nome, tipo, patrimonio, marca, modelo, status, data_garantia,
   vida_util_estimada_meses, numero_serie, condicao,
   id_localizacao_atual, id_usuario_responsavel)
SELECT 'TCC Test Laptop B', 'Notebook', 'TCC_TEST_PAT_002', 'Dell', 'Latitude Test',
       'Bloqueado', DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 48,
       'TCC_TEST_SN_002', 'RUIM', @location_a, @owner_a
WHERE NOT EXISTS (SELECT 1 FROM equipamentos WHERE patrimonio = 'TCC_TEST_PAT_002');

SET @laptop_a := (SELECT id FROM equipamentos WHERE patrimonio = 'TCC_TEST_PAT_001');
SET @laptop_b := (SELECT id FROM equipamentos WHERE patrimonio = 'TCC_TEST_PAT_002');

-- Purchase items: quantity 1 per individually identified physical asset.
INSERT INTO itens_compra (id_equipamento, id_compra, quantidade, vlr_unitario, lote, tipo_entrada)
SELECT @laptop_a, @purchase, 1, 4500.00, 'TCC_TEST_LOT_001', 'Compra'
WHERE NOT EXISTS (SELECT 1 FROM itens_compra WHERE id_equipamento = @laptop_a AND id_compra = @purchase);
INSERT INTO itens_compra (id_equipamento, id_compra, quantidade, vlr_unitario, lote, tipo_entrada)
SELECT @laptop_b, @purchase, 1, 4500.00, 'TCC_TEST_LOT_001', 'Compra'
WHERE NOT EXISTS (SELECT 1 FROM itens_compra WHERE id_equipamento = @laptop_b AND id_compra = @purchase);

-- Computer specifications: new hostname + IPv6-compatible endereco_ip.
-- 2001:db8::/32 and 192.0.2.0/24 are documentation-only IP ranges.
INSERT INTO especificacoes_computador
  (id_equipamento, processador, memoria_ram_gb, armazenamento_gb,
   tipo_armazenamento, sistema_operacional, mac_address, endereco_ip, hostname)
SELECT @laptop_a, 'Intel Core i5 (test)', 16, 512, 'SSD', 'Ubuntu Linux',
       '02:00:00:00:00:11', '2001:db8::101', 'tcc-test-laptop-a'
WHERE NOT EXISTS (SELECT 1 FROM especificacoes_computador WHERE id_equipamento = @laptop_a);
INSERT INTO especificacoes_computador
  (id_equipamento, processador, memoria_ram_gb, armazenamento_gb,
   tipo_armazenamento, sistema_operacional, mac_address, endereco_ip, hostname)
SELECT @laptop_b, 'Intel Core i5 (test)', 16, 512, 'SSD', 'Ubuntu Linux',
       '02:00:00:00:00:12', '192.0.2.102', 'tcc-test-laptop-b'
WHERE NOT EXISTS (SELECT 1 FROM especificacoes_computador WHERE id_equipamento = @laptop_b);

-- =====================================================================
-- C. FLOW: TRANSFER LAPTOP A FROM STORAGE/EMPLOYEE A TO LAB/EMPLOYEE B
-- =====================================================================
-- Existing columns: id_usuario = operator; id_localizacao = destination.
-- New columns: origin, old/new responsible persons and movement date.
INSERT INTO movimentacao
  (id_equipamento, id_usuario, id_localizacao, quantidade, centro_custo,
   tp_movimento, vlr_movimento, observacao, data_movimentacao,
   id_localizacao_origem, id_responsavel_anterior, id_responsavel_novo)
SELECT @laptop_a, @operator, @location_b, 1, 'TCC_TEST_IT',
       'TRANSFERENCIA', 0.00, 'TCC_TEST_TRANSFER_001', NOW(),
       @location_a, @owner_a, @owner_b
WHERE NOT EXISTS
  (SELECT 1 FROM movimentacao
   WHERE id_equipamento = @laptop_a AND observacao = 'TCC_TEST_TRANSFER_001');

-- Both operations must be in the same transaction in the Spring Boot API.
UPDATE equipamentos
SET id_localizacao_atual = @location_b,
    id_usuario_responsavel = @owner_b,
    status = 'Ativo'
WHERE id = @laptop_a AND patrimonio = 'TCC_TEST_PAT_001';

-- =====================================================================
-- D. FLOW: BLOCK LAPTOP B; RECORD WHO BLOCKED IT + ASSET EVALUATION
-- =====================================================================
INSERT INTO bloqueio_equipamento
  (id_equipamento, motivo, data_bloq, id_usuario_registro)
SELECT @laptop_b, 'TCC_TEST_BLOCK_001 - Damaged keyboard', NOW(), @operator
WHERE NOT EXISTS
  (SELECT 1 FROM bloqueio_equipamento
   WHERE id_equipamento = @laptop_b AND motivo = 'TCC_TEST_BLOCK_001 - Damaged keyboard');

UPDATE equipamentos
SET status = 'Bloqueado', condicao = 'RUIM'
WHERE id = @laptop_b AND patrimonio = 'TCC_TEST_PAT_002';

INSERT INTO avaliacao_ativos
  (id_equipamento, id_usuario_testador, valor_avaliado, resultado_teste, observacoes_tecnicas)
SELECT @laptop_b, @operator, 1200.00, 'REPARO_NECESSARIO',
       'TCC_TEST_EVALUATION_001 - Keyboard replacement recommended'
WHERE NOT EXISTS
  (SELECT 1 FROM avaliacao_ativos
   WHERE id_equipamento = @laptop_b AND observacoes_tecnicas =
         'TCC_TEST_EVALUATION_001 - Keyboard replacement recommended');

-- =====================================================================
-- E. SOFTWARE LICENSES AND INSTALLATIONS / UNINSTALLATIONS
-- =====================================================================
INSERT INTO softwares
  (nome, fabricante, versao, tipo_licenca, data_expiracao_licenca, quantidade_licencas)
SELECT 'TCC_TEST_Office_Lab', 'Fictional Test Vendor', '1.0', 'COMERCIAL',
       DATE_ADD(CURDATE(), INTERVAL 90 DAY), 2
WHERE NOT EXISTS (SELECT 1 FROM softwares WHERE nome = 'TCC_TEST_Office_Lab');

INSERT INTO softwares
  (nome, fabricante, versao, tipo_licenca, data_expiracao_licenca, quantidade_licencas)
SELECT 'TCC_TEST_OpenSource', 'Fictional Test Project', '1.0', 'LIVRE', NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM softwares WHERE nome = 'TCC_TEST_OpenSource');

SET @software_paid := (SELECT id FROM softwares WHERE nome = 'TCC_TEST_Office_Lab' ORDER BY id LIMIT 1);
SET @software_free := (SELECT id FROM softwares WHERE nome = 'TCC_TEST_OpenSource' ORDER BY id LIMIT 1);

-- Active commercial installation on laptop A.
INSERT INTO instalacoes_software
  (id_equipamento, id_software, data_instalacao, data_desinstalacao)
SELECT @laptop_a, @software_paid, DATE_SUB(NOW(), INTERVAL 5 DAY), NULL
WHERE NOT EXISTS
  (SELECT 1 FROM instalacoes_software WHERE id_equipamento = @laptop_a AND id_software = @software_paid);

-- Previously uninstalled commercial software on laptop B.
INSERT INTO instalacoes_software
  (id_equipamento, id_software, data_instalacao, data_desinstalacao)
SELECT @laptop_b, @software_paid,
       DATE_SUB(NOW(), INTERVAL 7 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY)
WHERE NOT EXISTS
  (SELECT 1 FROM instalacoes_software WHERE id_equipamento = @laptop_b AND id_software = @software_paid);

-- Open-source software with NULL license count (= not tracked).
INSERT INTO instalacoes_software
  (id_equipamento, id_software, data_instalacao, data_desinstalacao)
SELECT @laptop_a, @software_free, DATE_SUB(NOW(), INTERVAL 2 DAY), NULL
WHERE NOT EXISTS
  (SELECT 1 FROM instalacoes_software WHERE id_equipamento = @laptop_a AND id_software = @software_free);

COMMIT;

-- =====================================================================
-- F. AUTOMATED CHECKS: PASS / FAIL (no hand-written INSERT tests needed)
-- =====================================================================
-- Result should show ALL checks = PASS and tests_failed = 0.
WITH checks AS (
  SELECT '01 | New equipment columns exist' AS test_name,
    CASE WHEN (
      SELECT COUNT(DISTINCT COLUMN_NAME)
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'equipamentos'
        AND COLUMN_NAME IN ('numero_serie', 'condicao', 'id_localizacao_atual',
                            'id_usuario_responsavel', 'data_cadastro')
    ) = 5 THEN 1 ELSE 0 END AS passed

  UNION ALL SELECT '02 | New movement columns exist',
    CASE WHEN (
      SELECT COUNT(DISTINCT COLUMN_NAME)
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'movimentacao'
        AND COLUMN_NAME IN ('data_movimentacao', 'id_localizacao_origem',
                            'id_responsavel_anterior', 'id_responsavel_novo')
    ) = 4 THEN 1 ELSE 0 END

  UNION ALL SELECT '03 | IP column supports IPv6 (45 chars)',
    CASE WHEN EXISTS (
      SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'especificacoes_computador'
        AND COLUMN_NAME = 'endereco_ip' AND CHARACTER_MAXIMUM_LENGTH >= 45
    ) THEN 1 ELSE 0 END

  UNION ALL SELECT '04 | All other Step 1 fields exist',
    CASE WHEN (
      SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND (
         (TABLE_NAME = 'especificacoes_computador' AND COLUMN_NAME = 'hostname') OR
         (TABLE_NAME = 'bloqueio_equipamento' AND COLUMN_NAME = 'id_usuario_registro') OR
         (TABLE_NAME = 'softwares' AND COLUMN_NAME = 'quantidade_licencas') OR
         (TABLE_NAME = 'instalacoes_software' AND COLUMN_NAME = 'data_desinstalacao') OR
         (TABLE_NAME = 'usuarios' AND COLUMN_NAME = 'ativo')
      )
    ) = 5 THEN 1 ELSE 0 END

  UNION ALL SELECT '05 | New foreign keys present (6)',
    CASE WHEN (
      SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, '.', COLUMN_NAME))
      FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
      WHERE TABLE_SCHEMA = DATABASE() AND REFERENCED_TABLE_NAME IS NOT NULL
        AND ((TABLE_NAME = 'equipamentos'
              AND COLUMN_NAME IN ('id_localizacao_atual', 'id_usuario_responsavel'))
          OR (TABLE_NAME = 'movimentacao'
              AND COLUMN_NAME IN ('id_localizacao_origem', 'id_responsavel_anterior',
                                  'id_responsavel_novo'))
          OR (TABLE_NAME = 'bloqueio_equipamento'
              AND COLUMN_NAME = 'id_usuario_registro'))
    ) = 6 THEN 1 ELSE 0 END

  UNION ALL SELECT '06 | New unique indexes present (3)',
    CASE WHEN (
      SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME))
      FROM INFORMATION_SCHEMA.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND NON_UNIQUE = 0
        AND ((TABLE_NAME = 'equipamentos' AND INDEX_NAME = 'uq_equipamentos_numero_serie')
          OR (TABLE_NAME = 'roles' AND INDEX_NAME = 'uq_roles_nome')
          OR (TABLE_NAME = 'usuarios_roles' AND INDEX_NAME = 'uq_usuarios_roles_par'))
    ) = 3 THEN 1 ELSE 0 END

  UNION ALL SELECT '07 | New CHECK constraints present (3)',
    CASE WHEN (
      SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = DATABASE() AND CONSTRAINT_TYPE = 'CHECK'
        AND ((TABLE_NAME = 'equipamentos' AND CONSTRAINT_NAME = 'chk_equipamentos_condicao')
          OR (TABLE_NAME = 'softwares' AND CONSTRAINT_NAME = 'chk_softwares_quantidade_licencas')
          OR (TABLE_NAME = 'usuarios' AND CONSTRAINT_NAME = 'chk_usuarios_ativo'))
    ) = 3 THEN 1 ELSE 0 END

  UNION ALL SELECT '08 | Two distinct physical assets',
    CASE WHEN (
      SELECT COUNT(*) FROM equipamentos
      WHERE patrimonio IN ('TCC_TEST_PAT_001', 'TCC_TEST_PAT_002')
        AND numero_serie IN ('TCC_TEST_SN_001', 'TCC_TEST_SN_002')
        AND data_cadastro IS NOT NULL
    ) = 2 THEN 1 ELSE 0 END

  UNION ALL SELECT '09 | Laptop A has hostname and IPv6',
    CASE WHEN EXISTS (
      SELECT 1 FROM especificacoes_computador
      WHERE id_equipamento = @laptop_a AND hostname = 'tcc-test-laptop-a'
        AND endereco_ip = '2001:db8::101'
    ) THEN 1 ELSE 0 END

  UNION ALL SELECT '10 | Purchase has 2 items, quantity 1',
    CASE WHEN (
      SELECT COUNT(*) FROM itens_compra
      WHERE id_compra = @purchase AND id_equipamento IN (@laptop_a, @laptop_b)
        AND quantidade = 1 AND vlr_unitario = 4500.00
    ) = 2 THEN 1 ELSE 0 END

  UNION ALL SELECT '11 | Movement history records origin/destination/owners',
    CASE WHEN EXISTS (
      SELECT 1 FROM movimentacao
      WHERE id_equipamento = @laptop_a AND observacao = 'TCC_TEST_TRANSFER_001'
        AND id_usuario = @operator AND quantidade = 1
        AND id_localizacao_origem = @location_a AND id_localizacao = @location_b
        AND id_responsavel_anterior = @owner_a AND id_responsavel_novo = @owner_b
        AND data_movimentacao IS NOT NULL
    ) THEN 1 ELSE 0 END

  UNION ALL SELECT '12 | Current location/owner updated after movement',
    CASE WHEN EXISTS (
      SELECT 1 FROM equipamentos
      WHERE id = @laptop_a AND id_localizacao_atual = @location_b
        AND id_usuario_responsavel = @owner_b AND status = 'Ativo'
    ) THEN 1 ELSE 0 END

  UNION ALL SELECT '13 | Rerun creates no duplicate transfer',
    CASE WHEN (
      SELECT COUNT(*) FROM movimentacao
      WHERE id_equipamento = @laptop_a AND observacao = 'TCC_TEST_TRANSFER_001'
    ) = 1 THEN 1 ELSE 0 END

  UNION ALL SELECT '14 | Blocked laptop records operator/condition',
    CASE WHEN EXISTS (
      SELECT 1 FROM bloqueio_equipamento b JOIN equipamentos e ON e.id = b.id_equipamento
      WHERE b.id_equipamento = @laptop_b AND b.id_usuario_registro = @operator
        AND b.motivo = 'TCC_TEST_BLOCK_001 - Damaged keyboard'
        AND e.status = 'Bloqueado' AND e.condicao = 'RUIM'
    ) THEN 1 ELSE 0 END

  UNION ALL SELECT '15 | License pool = 2, open source = NULL',
    CASE WHEN (SELECT quantidade_licencas FROM softwares WHERE id = @software_paid) = 2
           AND (SELECT quantidade_licencas FROM softwares WHERE id = @software_free) IS NULL
      THEN 1 ELSE 0 END

  UNION ALL SELECT '16 | Software installation and removal captured',
    CASE WHEN EXISTS (
      SELECT 1 FROM instalacoes_software
      WHERE id_equipamento = @laptop_a AND id_software = @software_paid
        AND data_desinstalacao IS NULL
    ) AND EXISTS (
      SELECT 1 FROM instalacoes_software
      WHERE id_equipamento = @laptop_b AND id_software = @software_paid
        AND data_desinstalacao IS NOT NULL
        AND data_desinstalacao >= data_instalacao
    ) THEN 1 ELSE 0 END

  UNION ALL SELECT '17 | Active paid installs do not exceed licenses',
    CASE WHEN (
      SELECT COUNT(*) FROM instalacoes_software
      WHERE id_software = @software_paid AND data_desinstalacao IS NULL
    ) <= (SELECT quantidade_licencas FROM softwares WHERE id = @software_paid)
      THEN 1 ELSE 0 END

  UNION ALL SELECT '18 | Active/inactive users recorded',
    CASE WHEN EXISTS (SELECT 1 FROM usuarios WHERE id = @operator AND ativo = 1)
           AND EXISTS (SELECT 1 FROM usuarios WHERE id = @inactive AND ativo = 0)
      THEN 1 ELSE 0 END

  UNION ALL SELECT '19 | Roles assigned to seeded users',
    CASE WHEN EXISTS (
      SELECT 1 FROM usuarios_roles WHERE id_usuario = @operator AND id_role = @role_admin
    ) AND EXISTS (
      SELECT 1 FROM usuarios_roles WHERE id_usuario = @owner_b AND id_role = @role_user
    ) THEN 1 ELSE 0 END

  UNION ALL SELECT '20 | Evaluation of blocked asset recorded',
    CASE WHEN EXISTS (
      SELECT 1 FROM avaliacao_ativos
      WHERE id_equipamento = @laptop_b AND id_usuario_testador = @operator
        AND resultado_teste = 'REPARO_NECESSARIO' AND valor_avaliado = 1200.00
    ) THEN 1 ELSE 0 END
)
SELECT test_name,
       IF(passed = 1, 'PASS', 'FAIL') AS result,
       SUM(passed) OVER () AS total_passed,
       SUM(1 - passed) OVER () AS total_failed
FROM checks
ORDER BY test_name;

-- =====================================================================
-- G. OPTIONAL VISUAL RESULTS: EASY TO INSPECT IN DBEAVER
-- =====================================================================
-- 1. Final equipment view: laptop A transferred, laptop B blocked.
SELECT e.patrimonio, e.nome, e.numero_serie, e.condicao, e.status,
       l.nome_local AS current_location, u.nome AS current_responsible,
       s.hostname, s.endereco_ip
FROM equipamentos e
LEFT JOIN localizacao l ON l.id = e.id_localizacao_atual
LEFT JOIN usuarios u ON u.id = e.id_usuario_responsavel
LEFT JOIN especificacoes_computador s ON s.id_equipamento = e.id
WHERE e.id IN (@laptop_a, @laptop_b)
ORDER BY e.patrimonio;

-- 2. Transfer history, including the operator and previous/new owners.
SELECT e.patrimonio, m.data_movimentacao,
       origem.nome_local AS origin_location,
       destino.nome_local AS destination_location,
       antes.nome AS previous_owner, depois.nome AS new_owner,
       operador.nome AS recorded_by, m.quantidade
FROM movimentacao m
JOIN equipamentos e ON e.id = m.id_equipamento
LEFT JOIN localizacao origem ON origem.id = m.id_localizacao_origem
LEFT JOIN localizacao destino ON destino.id = m.id_localizacao
LEFT JOIN usuarios antes ON antes.id = m.id_responsavel_anterior
LEFT JOIN usuarios depois ON depois.id = m.id_responsavel_novo
LEFT JOIN usuarios operador ON operador.id = m.id_usuario
WHERE m.id_equipamento = @laptop_a AND m.observacao = 'TCC_TEST_TRANSFER_001';

-- 3. Software licenses vs. currently active installations.
SELECT s.nome, s.tipo_licenca, s.quantidade_licencas,
       COUNT(i.id) AS active_installations,
       CASE WHEN s.quantidade_licencas IS NULL THEN 'NOT TRACKED'
            WHEN COUNT(i.id) <= s.quantidade_licencas THEN 'OK'
            ELSE 'OVER LIMIT' END AS license_status
FROM softwares s
LEFT JOIN instalacoes_software i
  ON i.id_software = s.id AND i.data_desinstalacao IS NULL
WHERE s.id IN (@software_paid, @software_free)
GROUP BY s.id, s.nome, s.tipo_licenca, s.quantidade_licencas
ORDER BY s.nome;

-- 4. All four test users; the last account should be inactive.
SELECT nome, email, cargo, ativo
FROM usuarios
WHERE id IN (@operator, @owner_a, @owner_b, @inactive)
ORDER BY email;

-- Note: The original 'estoque' table is not populated in this test.
--       It is outside the one-row-per-physical-asset MVP model.
--       No Step 2 tables (manutencoes/descartes/ocorrencias_seguranca)
--       are needed for this script.
