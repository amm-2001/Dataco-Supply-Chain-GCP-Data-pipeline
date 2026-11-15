-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : markets
-- Load order : 01  (data file: data/01_markets.sql)
-- Depends on : -
-- Grain      : one row per sales market
-- Source cols: Market
-- =============================================================================

CREATE TABLE markets (
  market_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  market_name  VARCHAR(30)      NOT NULL               COMMENT 'Market where the order is delivered (Africa, Europe, LATAM, Pacific Asia, USCA)',
  CONSTRAINT pk_markets PRIMARY KEY (market_id),
  CONSTRAINT uq_markets_name UNIQUE (market_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Top level of the delivery geography: commercial market';
