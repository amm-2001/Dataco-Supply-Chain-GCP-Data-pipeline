-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : countries
-- Load order : 03  (data file: data/03_countries.sql)
-- Depends on : -
-- Grain      : one row per country
-- Source cols: Order Country, Customer Country (translated to English)
-- =============================================================================

CREATE TABLE countries (
  country_id    SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  country_name  VARCHAR(60)       NOT NULL               COMMENT 'English country name',
  iso_alpha2    CHAR(2) CHARACTER SET ascii NOT NULL      COMMENT 'ISO 3166-1 alpha-2 code',
  CONSTRAINT pk_countries PRIMARY KEY (country_id),
  CONSTRAINT uq_countries_name UNIQUE (country_name),
  CONSTRAINT uq_countries_iso UNIQUE (iso_alpha2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Shared country dimension for customer and order-destination addresses';
