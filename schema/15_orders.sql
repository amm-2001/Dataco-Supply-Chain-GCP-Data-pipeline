-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : orders
-- Load order : 15  (data file: data/15_orders.sql)
-- Depends on : customers, payment_types, order_statuses, cities
-- Grain      : one row per order (order header)
-- Source cols: Order Id, Order Customer Id, order date (DateOrders), Type, Order Status, Order City/State/Country, Order Zipcode
-- =============================================================================

CREATE TABLE orders (
  order_id             INT UNSIGNED     NOT NULL AUTO_INCREMENT COMMENT 'Source Order Id',
  customer_id          INT UNSIGNED     NOT NULL               COMMENT 'FK -> customers',
  order_datetime       DATETIME         NOT NULL               COMMENT 'Date and time the order was placed',
  payment_type_id      TINYINT UNSIGNED NOT NULL               COMMENT 'FK -> payment_types (source column Type)',
  order_status_id      TINYINT UNSIGNED NOT NULL               COMMENT 'FK -> order_statuses',
  destination_city_id  INT UNSIGNED     NOT NULL               COMMENT 'FK -> cities. Destination; state/country/region/market are derived through the hierarchy',
  destination_zipcode  VARCHAR(10)      NULL                   COMMENT 'Destination ZIP code (US orders only)',
  CONSTRAINT pk_orders PRIMARY KEY (order_id),
  CONSTRAINT fk_orders_customer     FOREIGN KEY (customer_id)         REFERENCES customers (customer_id),
  CONSTRAINT fk_orders_payment_type FOREIGN KEY (payment_type_id)     REFERENCES payment_types (payment_type_id),
  CONSTRAINT fk_orders_status       FOREIGN KEY (order_status_id)     REFERENCES order_statuses (order_status_id),
  CONSTRAINT fk_orders_dest_city    FOREIGN KEY (destination_city_id) REFERENCES cities (city_id),
  INDEX ix_orders_datetime (order_datetime),
  INDEX ix_orders_customer_datetime (customer_id, order_datetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Order header';
