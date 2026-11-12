-- =====================================================================
-- FATEC SBC | TCC STEP 2 - CORE SEED + AUTOMATED SMOKE TESTS
-- MySQL 8.x | DBeaver: Execute SQL Script (not one statement)
-- =====================================================================
-- PREREQUISITES:
--  1. Step 1 schema and its sample seed have already been executed.
--  2. TCC_Step_2_Core_Tables.sql has been executed.
-- SAFETY:
--  - LOCAL/TEST DATABASE ONLY; uses Step 1's TCC_TEST_* records.
--  - Never DROP / DELETE / TRUNCATE. Keeps sample records for inspection.
--  - Changes the status of ONLY TCC_TEST_PAT_002 to 'Descartado'.
--  - Reruns reuse marked test records rather than duplicating them.
--  - Before running on a shared database, back up the schema and data.
--  - If any statement fails, STOP script execution and investigate.
-- =====================================================================

USE sistema_ti;

-- Fail early if Step 1's seed has not been loaded.
-- A missing test ID triggers a NOT NULL / foreign-key failure instead
-- of silently creating a business record against another equipment.
SET @test_operator := (
  SELECT id FROM usuarios
  WHERE email = 'tcc.test.operator@example.invalid'
  ORDER BY id LIMIT 1
);
SET @test_laptop_a := (
  SELECT id FROM equipamentos
  WHERE patrimonio = 'TCC_TEST_PAT_001'
  ORDER BY id LIMIT 1
);
SET @test_laptop_b := (
  SELECT id FROM equipamentos
  WHERE patrimonio = 'TCC_TEST_PAT_002'
  ORDER BY id LIMIT 1
);

START TRANSACTION;

-- A. Preventive maintenance on Laptop A: opened, completed, cost paid.
INSERT INTO manutencoes
  (id_equipamento, id_usuario_registro, tipo, descricao,
   data_abertura, data_conclusao, status, custo)
SELECT @test_laptop_a, @test_operator, 'PREVENTIVA',
       'TCC_TEST_STEP2_MAINT_A - Cleaning and performance inspection',
       DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY),
       'CONCLUIDA', 75.00
WHERE NOT EXISTS (
  SELECT 1 FROM manutencoes
  WHERE id_equipamento = @test_laptop_a
    AND descricao = 'TCC_TEST_STEP2_MAINT_A - Cleaning and performance inspection'
);

-- B. Laptop B is already blocked in Step 1. Record its final disposal.
INSERT INTO descartes
  (id_equipamento, id_usuario_responsavel, data_descarte,
   tipo_destinacao, motivo, observacoes)
SELECT @test_laptop_b, @test_operator, CURDATE(),
       'RECICLAGEM', 'TCC_TEST_STEP2_DISPOSAL_B - Asset beyond economic repair',
       'Test recycling entry; the historical asset record is retained'
WHERE NOT EXISTS (
  SELECT 1 FROM descartes
  WHERE id_equipamento = @test_laptop_b
);

-- A disposal record and the equipment state must be changed together.
-- This is an illustration of what the application's @Transactional
-- service should do.
UPDATE equipamentos
SET status = 'Descartado'
WHERE id = @test_laptop_b
  AND patrimonio = 'TCC_TEST_PAT_002'
  AND EXISTS (
    SELECT 1 FROM descartes
    WHERE id_equipamento = @test_laptop_b
      AND motivo = 'TCC_TEST_STEP2_DISPOSAL_B - Asset beyond economic repair'
  );

COMMIT;

-- C. PASS/FAIL checks: no manual inserts or calculations necessary.
WITH checks AS (
  SELECT '01 | Both new core tables exist' AS test_name,
    IF((SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name IN ('manutencoes', 'descartes')) = 2, 1, 0) AS passed

  UNION ALL SELECT '02 | Four foreign keys exist',
    IF((SELECT COUNT(*) FROM information_schema.key_column_usage
        WHERE table_schema = DATABASE() AND referenced_table_name IS NOT NULL
          AND ((table_name = 'manutencoes' AND column_name IN
                ('id_equipamento', 'id_usuario_registro'))
            OR (table_name = 'descartes' AND column_name IN
                ('id_equipamento', 'id_usuario_responsavel')))) = 4, 1, 0)

  UNION ALL SELECT '03 | Five CHECK constraints exist',
    IF((SELECT COUNT(*) FROM information_schema.table_constraints
        WHERE table_schema = DATABASE() AND constraint_type = 'CHECK'
          AND ((table_name = 'manutencoes' AND constraint_name IN
                ('chk_manutencoes_tipo', 'chk_manutencoes_status',
                 'chk_manutencoes_custo', 'chk_manutencoes_datas'))
            OR (table_name = 'descartes' AND constraint_name = 'chk_descartes_tipo')))
        = 5, 1, 0)

  UNION ALL SELECT '04 | Disposal is unique per asset',
    IF(EXISTS (
      SELECT 1 FROM information_schema.statistics
      WHERE table_schema = DATABASE() AND table_name = 'descartes'
        AND index_name = 'uq_descartes_equipamento'
        AND column_name = 'id_equipamento' AND non_unique = 0
    ), 1, 0)

  UNION ALL SELECT '05 | Maintenance is registered on Laptop A',
    IF(EXISTS (
      SELECT 1 FROM manutencoes
      WHERE id_equipamento = @test_laptop_a
        AND id_usuario_registro = @test_operator
        AND tipo = 'PREVENTIVA'
        AND descricao = 'TCC_TEST_STEP2_MAINT_A - Cleaning and performance inspection'
    ), 1, 0)

  UNION ALL SELECT '06 | Maintenance is completed and cost is 75',
    IF(EXISTS (
      SELECT 1 FROM manutencoes
      WHERE id_equipamento = @test_laptop_a
        AND status = 'CONCLUIDA' AND custo = 75.00
        AND data_conclusao >= data_abertura
        AND descricao = 'TCC_TEST_STEP2_MAINT_A - Cleaning and performance inspection'
    ), 1, 0)

  UNION ALL SELECT '07 | Laptop B has recycling disposal record',
    IF(EXISTS (
      SELECT 1 FROM descartes
      WHERE id_equipamento = @test_laptop_b
        AND id_usuario_responsavel = @test_operator
        AND tipo_destinacao = 'RECICLAGEM'
        AND motivo = 'TCC_TEST_STEP2_DISPOSAL_B - Asset beyond economic repair'
    ), 1, 0)

  UNION ALL SELECT '08 | Disposed laptop has correct status',
    IF(EXISTS (
      SELECT 1 FROM equipamentos
      WHERE id = @test_laptop_b
        AND patrimonio = 'TCC_TEST_PAT_002' AND status = 'Descartado'
    ), 1, 0)

  UNION ALL SELECT '09 | Original purchase and block history preserved',
    IF(EXISTS (
      SELECT 1 FROM itens_compra WHERE id_equipamento = @test_laptop_b
    ) AND EXISTS (
      SELECT 1 FROM bloqueio_equipamento WHERE id_equipamento = @test_laptop_b
    ), 1, 0)

  UNION ALL SELECT '10 | Rerun creates no duplicate test records',
    IF((SELECT COUNT(*) FROM manutencoes
        WHERE id_equipamento = @test_laptop_a
          AND descricao = 'TCC_TEST_STEP2_MAINT_A - Cleaning and performance inspection') = 1
       AND (SELECT COUNT(*) FROM descartes WHERE id_equipamento = @test_laptop_b) = 1,
       1, 0)
)
SELECT test_name,
       IF(passed = 1, 'PASS', 'FAIL') AS result,
       SUM(passed) OVER () AS total_passed,
       SUM(1 - passed) OVER () AS total_failed
FROM checks
ORDER BY test_name;

-- D. Easy-to-read evidence for DBeaver / the TCC demonstration.
SELECT e.patrimonio, m.tipo, m.descricao, m.status,
       m.data_abertura, m.data_conclusao, m.custo, u.nome AS registered_by
FROM manutencoes m
JOIN equipamentos e ON e.id = m.id_equipamento
JOIN usuarios u ON u.id = m.id_usuario_registro
WHERE e.patrimonio = 'TCC_TEST_PAT_001';

SELECT e.patrimonio, e.status AS equipment_status,
       d.data_descarte, d.tipo_destinacao, d.motivo,
       u.nome AS recorded_by
FROM descartes d
JOIN equipamentos e ON e.id = d.id_equipamento
JOIN usuarios u ON u.id = d.id_usuario_responsavel
WHERE e.patrimonio = 'TCC_TEST_PAT_002';

-- The optional security table is NOT needed for the ten core checks.
