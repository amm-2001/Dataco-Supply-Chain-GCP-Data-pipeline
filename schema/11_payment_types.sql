-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : payment_types
-- Load order : 11  (data file: data/11_payment_types.sql)
-- Depends on : -
-- Grain      : one row per transaction type
-- Source cols: Type
-- =============================================================================

CREATE TABLE payment_types (
  payment_type_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  payment_type_name  VARCHAR(30)      NOT NULL               COMMENT 'Type of transaction: CASH, DEBIT, PAYMENT, TRANSFER',
  CONSTRAINT pk_payment_types PRIMARY KEY (payment_type_id),
  CONSTRAINT uq_payment_types_name UNIQUE (payment_type_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Lookup: transaction / payment type';
