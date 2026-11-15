-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : delivery_statuses
-- Load order : 14  (data file: data/14_delivery_statuses.sql)
-- Depends on : -
-- Grain      : one row per delivery status
-- Source cols: Delivery Status, Late_delivery_risk
-- =============================================================================

CREATE TABLE delivery_statuses (
  delivery_status_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  delivery_status_name  VARCHAR(30)      NOT NULL               COMMENT 'Advance shipping, Late delivery, Shipping canceled, Shipping on time',
  late_delivery_risk    TINYINT UNSIGNED NOT NULL               COMMENT '1 = delivery is late, 0 = not late',
  CONSTRAINT pk_delivery_statuses PRIMARY KEY (delivery_status_id),
  CONSTRAINT uq_delivery_statuses_name UNIQUE (delivery_status_name),
  CONSTRAINT ck_delivery_statuses_risk CHECK (late_delivery_risk IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Lookup: delivery status; Delivery Status -> late delivery risk';
