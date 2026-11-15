-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : order_items
-- Load order : 17  (data file: data/17_order_items.sql)
-- Depends on : orders, products
-- Grain      : one row per order line (the grain of the source file)
-- Source cols: Order Item Id, Order Id, Product Card Id, Order Item Quantity, Order Item Product Price, Sales, Order Item Discount Rate, Order Item Discount, Order Item Total (= Sales per customer), Order Item Profit Ratio, Order Profit Per Order (= Benefit per order)
-- =============================================================================

CREATE TABLE order_items (
  order_item_id    INT UNSIGNED      NOT NULL AUTO_INCREMENT COMMENT 'Source Order Item Id',
  order_id         INT UNSIGNED      NOT NULL               COMMENT 'FK -> orders',
  product_id       INT UNSIGNED      NOT NULL               COMMENT 'FK -> products',
  quantity         SMALLINT UNSIGNED NOT NULL               COMMENT 'Number of units on the line',
  unit_price       DECIMAL(10,2)     NOT NULL               COMMENT 'Unit price at time of sale, before discount (Order Item Product Price)',
  gross_sales      DECIMAL(12,2) GENERATED ALWAYS AS (unit_price * quantity) STORED
                                                            COMMENT 'Sales value before discount (source column Sales) - derived, never loaded',
  discount_rate    DECIMAL(5,4)      NOT NULL DEFAULT 0     COMMENT 'Discount percentage as a fraction, e.g. 0.0400 = 4%',
  discount_amount  DECIMAL(10,2)     NOT NULL DEFAULT 0     COMMENT 'Discount value (Order Item Discount)',
  net_sales        DECIMAL(12,2)     NOT NULL               COMMENT 'Line total after discount (Order Item Total = Sales per customer)',
  profit_ratio     DECIMAL(6,4)      NOT NULL               COMMENT 'Profit ratio of the line (Order Item Profit Ratio)',
  profit           DECIMAL(12,2)     NOT NULL               COMMENT 'Profit of the line (Order Profit Per Order = Benefit per order)',
  CONSTRAINT pk_order_items PRIMARY KEY (order_item_id),
  CONSTRAINT fk_order_items_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id) ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (product_id),
  CONSTRAINT ck_order_items_qty      CHECK (quantity > 0),
  CONSTRAINT ck_order_items_price    CHECK (unit_price >= 0),
  CONSTRAINT ck_order_items_disc_pct CHECK (discount_rate BETWEEN 0 AND 1),
  CONSTRAINT ck_order_items_disc_amt CHECK (discount_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Order line - the fact grain of the dataset';
