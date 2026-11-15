-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : states
-- Load order : 04  (data file: data/04_states.sql)
-- Depends on : countries, regions
-- Grain      : one row per state / province within a country
-- Source cols: Order State, Customer State (translated; US codes resolved to names)
-- =============================================================================

CREATE TABLE states (
  state_id    SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  country_id  SMALLINT UNSIGNED NOT NULL               COMMENT 'FK -> countries',
  state_name  VARCHAR(80)       NOT NULL               COMMENT 'English state / province name',
  state_code  VARCHAR(3)        NULL                   COMMENT 'Postal code (US and Puerto Rico only), e.g. CA',
  region_id   TINYINT UNSIGNED  NULL                   COMMENT 'FK -> regions. NULL when no order was ever delivered to this state',
  CONSTRAINT pk_states PRIMARY KEY (state_id),
  CONSTRAINT uq_states_country_name UNIQUE (country_id, state_name),
  CONSTRAINT uq_states_country_code UNIQUE (country_id, state_code),
  CONSTRAINT fk_states_country FOREIGN KEY (country_id) REFERENCES countries (country_id),
  CONSTRAINT fk_states_region  FOREIGN KEY (region_id)  REFERENCES regions (region_id),
  INDEX ix_states_region (region_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='State / province; (country, state) -> region';
