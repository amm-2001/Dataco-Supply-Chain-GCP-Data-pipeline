-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : order_statuses
-- Load order : 12  (data file: data/12_order_statuses.sql)
-- Depends on : -
-- Grain      : one row per order status
-- Source cols: Order Status
-- =============================================================================

CREATE TABLE order_statuses (
  order_status_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  order_status_name  VARCHAR(30)      NOT NULL               COMMENT 'COMPLETE, PENDING, CLOSED, PENDING_PAYMENT, CANCELED, PROCESSING, SUSPECTED_FRAUD, ON_HOLD, PAYMENT_REVIEW',
  CONSTRAINT pk_order_statuses PRIMARY KEY (order_status_id),
  CONSTRAINT uq_order_statuses_name UNIQUE (order_status_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Lookup: order status';
