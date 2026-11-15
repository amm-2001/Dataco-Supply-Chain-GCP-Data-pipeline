-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : regions
-- Load order : 02  (data file: data/02_regions.sql)
-- Depends on : markets
-- Grain      : one row per world sales region
-- Source cols: Order Region (-> Market)
-- =============================================================================

CREATE TABLE regions (
  region_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  region_name  VARCHAR(50)      NOT NULL               COMMENT 'Region of the world where orders are delivered',
  market_id    TINYINT UNSIGNED NOT NULL               COMMENT 'FK -> markets. Every region belongs to exactly one market',
  CONSTRAINT pk_regions PRIMARY KEY (region_id),
  CONSTRAINT uq_regions_name UNIQUE (region_name),
  CONSTRAINT fk_regions_market FOREIGN KEY (market_id) REFERENCES markets (market_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Sales/delivery region; Order Region -> Market';
