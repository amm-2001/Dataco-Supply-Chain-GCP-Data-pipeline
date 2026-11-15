-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : customers
-- Load order : 10  (data file: data/10_customers.sql)
-- Depends on : customer_segments, cities
-- Grain      : one row per customer
-- Source cols: Customer Id / Order Customer Id, Customer Fname, Customer Lname, Customer Email, Customer Segment, Customer Street, Customer City/State/Country, Customer Zipcode, Latitude, Longitude
-- =============================================================================

CREATE TABLE customers (
  customer_id  INT UNSIGNED     NOT NULL AUTO_INCREMENT COMMENT 'Source Customer Id (= Order Customer Id)',
  first_name   VARCHAR(50)      NOT NULL               COMMENT 'Customer first name',
  last_name    VARCHAR(50)      NULL                   COMMENT 'Customer last name (8 customers have none in source)',
  email        VARCHAR(254)     NULL                   COMMENT 'Customer e-mail (masked in source -> NULL)',
  segment_id   TINYINT UNSIGNED NOT NULL               COMMENT 'FK -> customer_segments',
  street       VARCHAR(100)     NULL                   COMMENT 'Street of the store where the purchase is registered',
  city_id      INT UNSIGNED     NOT NULL               COMMENT 'FK -> cities (city -> state -> country)',
  zipcode      VARCHAR(10)      NULL                   COMMENT 'ZIP code as text (leading zeros preserved, e.g. 00725)',
  latitude     DECIMAL(10,8)    NULL                   COMMENT 'Latitude of the store location',
  longitude    DECIMAL(11,8)    NULL                   COMMENT 'Longitude of the store location',
  CONSTRAINT pk_customers PRIMARY KEY (customer_id),
  CONSTRAINT uq_customers_email UNIQUE (email),
  CONSTRAINT fk_customers_segment FOREIGN KEY (segment_id) REFERENCES customer_segments (segment_id),
  CONSTRAINT fk_customers_city    FOREIGN KEY (city_id)    REFERENCES cities (city_id),
  CONSTRAINT ck_customers_lat CHECK (latitude  BETWEEN -90  AND 90),
  CONSTRAINT ck_customers_lon CHECK (longitude BETWEEN -180 AND 180),
  INDEX ix_customers_name (last_name, first_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Customer master data with registered store address';
