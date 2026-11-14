-- =============================================================
-- STEP 3: Automated checks for the inventory deduction trigger.
-- This script leaves no test records in the database.
-- =============================================================

USE sistema_ti;

SELECT
  '01 | Inventory deduction trigger exists' AS test_name,
  CASE WHEN EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.TRIGGERS
    WHERE TRIGGER_SCHEMA = DATABASE()
      AND TRIGGER_NAME = 'trg_movimentacao_deduct_inventory_after_insert'
  ) THEN 'PASS' ELSE 'FAIL' END AS result;

START TRANSACTION;

SET @test_asset_code = CONCAT('TCC_TRIGGER_TEST_', REPLACE(UUID(), '-', ''));

INSERT INTO equipamentos (nome, patrimonio)
VALUES ('TCC Trigger Test Asset', @test_asset_code);

SET @test_asset_id = LAST_INSERT_ID();

INSERT INTO estoque (id_equipamento, estoque_atual, vlr_estoque)
VALUES (@test_asset_id, 5, 0.00);

INSERT INTO movimentacao (id_equipamento, quantidade, tp_movimento, observacao)
VALUES (@test_asset_id, 2, 'LOSS', 'TCC_TRIGGER_TEST_LOSS');

INSERT INTO movimentacao (id_equipamento, quantidade, tp_movimento, observacao)
VALUES (@test_asset_id, 1, 'DISCARD', 'TCC_TRIGGER_TEST_DISCARD');

SELECT
  '02 | LOSS and DISCARD deduct inventory' AS test_name,
  5 AS initial_inventory,
  2 AS expected_inventory,
  estoque_atual AS actual_inventory,
  CASE WHEN estoque_atual = 2 THEN 'PASS' ELSE 'FAIL' END AS result
FROM estoque
WHERE id_equipamento = @test_asset_id;

ROLLBACK;

SELECT
  '03 | Test data was rolled back' AS test_name,
  CASE WHEN NOT EXISTS (
    SELECT 1 FROM equipamentos WHERE patrimonio = @test_asset_code
  ) THEN 'PASS' ELSE 'FAIL' END AS result;
