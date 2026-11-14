-- =============================================================
-- STEP 3: Deduct inventory for loss and discard movements.
-- Movement types are stored in English: DISCARD and LOSS.
-- =============================================================

USE sistema_ti;

DELIMITER $$

CREATE TRIGGER trg_movimentacao_deduct_inventory_after_insert
AFTER INSERT ON movimentacao
FOR EACH ROW
BEGIN
  DECLARE inventory_row_count INT DEFAULT 0;

  IF UPPER(TRIM(COALESCE(NEW.tp_movimento, ''))) IN ('DISCARD', 'LOSS') THEN
    IF NEW.quantidade <= 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Discard and loss movements require a positive quantity';
    END IF;

    SELECT COUNT(*)
    INTO inventory_row_count
    FROM estoque
    WHERE id_equipamento = NEW.id_equipamento;

    IF inventory_row_count <> 1 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Each asset must have exactly one inventory record';
    END IF;

    UPDATE estoque
    SET estoque_atual = estoque_atual - NEW.quantidade
    WHERE id_equipamento = NEW.id_equipamento
      AND estoque_atual >= NEW.quantidade;

    IF ROW_COUNT() = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient inventory for discard or loss movement';
    END IF;
  END IF;
END$$

DELIMITER ;

-- Verification:
SHOW TRIGGERS WHERE `Trigger` = 'trg_movimentacao_deduct_inventory_after_insert';
