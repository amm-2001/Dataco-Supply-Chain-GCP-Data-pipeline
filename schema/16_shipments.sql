-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : shipments
-- Load order : 16  (data file: data/16_shipments.sql)
-- Depends on : orders, shipping_modes, delivery_statuses
-- Grain      : one row per shipment (currently exactly one per order)
-- Source cols: shipping date (DateOrders), Shipping Mode, Days for shipping (real), Delivery Status
-- =============================================================================

CREATE TABLE shipments (
  shipment_id           INT UNSIGNED     NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
  order_id              INT UNSIGNED     NOT NULL               COMMENT 'FK -> orders. UNIQUE = 1:1 today; drop uq_shipments_order to allow split shipments',
  shipping_mode_id      TINYINT UNSIGNED NOT NULL               COMMENT 'FK -> shipping_modes (gives scheduled days)',
  shipping_datetime     DATETIME         NOT NULL               COMMENT 'Exact date and time of shipment',
  actual_shipping_days  TINYINT UNSIGNED NOT NULL               COMMENT 'Actual shipping days of the purchased product (Days for shipping (real))',
  delivery_status_id    TINYINT UNSIGNED NOT NULL               COMMENT 'FK -> delivery_statuses (gives late_delivery_risk)',
  CONSTRAINT pk_shipments PRIMARY KEY (shipment_id),
  CONSTRAINT uq_shipments_order UNIQUE (order_id),
  CONSTRAINT fk_shipments_order    FOREIGN KEY (order_id)           REFERENCES orders (order_id) ON DELETE CASCADE,
  CONSTRAINT fk_shipments_mode     FOREIGN KEY (shipping_mode_id)   REFERENCES shipping_modes (shipping_mode_id),
  CONSTRAINT fk_shipments_delivery FOREIGN KEY (delivery_status_id) REFERENCES delivery_statuses (delivery_status_id),
  INDEX ix_shipments_datetime (shipping_datetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Fulfilment / shipping facts for an order';
