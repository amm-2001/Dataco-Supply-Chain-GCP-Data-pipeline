-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : shipping_modes
-- Load order : 13  (data file: data/13_shipping_modes.sql)
-- Depends on : -
-- Grain      : one row per shipping mode
-- Source cols: Shipping Mode, Days for shipment (scheduled)
-- =============================================================================

CREATE TABLE shipping_modes (
  shipping_mode_id         TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  shipping_mode_name       VARCHAR(30)      NOT NULL               COMMENT 'Standard Class, First Class, Second Class, Same Day',
  scheduled_shipping_days  TINYINT UNSIGNED NOT NULL               COMMENT 'Scheduled delivery days (SLA) for this mode',
  CONSTRAINT pk_shipping_modes PRIMARY KEY (shipping_mode_id),
  CONSTRAINT uq_shipping_modes_name UNIQUE (shipping_mode_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Lookup: shipping mode; Shipping Mode -> scheduled days';
