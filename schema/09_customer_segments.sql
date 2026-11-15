-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : customer_segments
-- Load order : 09  (data file: data/09_customer_segments.sql)
-- Depends on : -
-- Grain      : one row per customer segment
-- Source cols: Customer Segment
-- =============================================================================

CREATE TABLE customer_segments (
  segment_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  segment_name  VARCHAR(30)      NOT NULL               COMMENT 'Consumer, Corporate, Home Office',
  CONSTRAINT pk_customer_segments PRIMARY KEY (segment_id),
  CONSTRAINT uq_customer_segments_name UNIQUE (segment_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Lookup: customer segment';
