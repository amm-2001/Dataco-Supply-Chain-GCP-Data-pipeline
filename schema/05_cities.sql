-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : cities
-- Load order : 05  (data file: data/05_cities.sql)
-- Depends on : states
-- Grain      : one row per city within a state
-- Source cols: Order City, Customer City (translated to English)
-- =============================================================================

CREATE TABLE cities (
  city_id    INT UNSIGNED      NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  state_id   SMALLINT UNSIGNED NOT NULL               COMMENT 'FK -> states',
  city_name  VARCHAR(60)       NOT NULL               COMMENT 'English city name',
  CONSTRAINT pk_cities PRIMARY KEY (city_id),
  CONSTRAINT uq_cities_state_name UNIQUE (state_id, city_name),
  CONSTRAINT fk_cities_state FOREIGN KEY (state_id) REFERENCES states (state_id),
  INDEX ix_cities_name (city_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='City; lowest level of the shared geography hierarchy';
