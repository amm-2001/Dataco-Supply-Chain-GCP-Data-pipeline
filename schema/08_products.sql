-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : products
-- Load order : 08  (data file: data/08_products.sql)
-- Depends on : categories
-- Grain      : one row per product (catalogue item)
-- Source cols: Product Card Id / Order Item Cardprod Id, Product Name, Product Price, Product Image, Product Description, Product Status, Product Category Id
-- =============================================================================

CREATE TABLE products (
  product_id           INT UNSIGNED      NOT NULL AUTO_INCREMENT COMMENT 'Source Product Card Id (= Order Item Cardprod Id)',
  product_name         VARCHAR(100)      NOT NULL               COMMENT 'Product name',
  category_id          SMALLINT UNSIGNED NOT NULL               COMMENT 'FK -> categories',
  product_price        DECIMAL(10,2)     NOT NULL               COMMENT 'Current list price (without discount)',
  product_image_url    VARCHAR(255)      NULL                   COMMENT 'Link to view / buy the product',
  product_description  TEXT              NULL                   COMMENT 'Product description (empty in source)',
  product_status       TINYINT UNSIGNED  NOT NULL DEFAULT 0     COMMENT 'Stock status: 0 = available, 1 = not available',
  CONSTRAINT pk_products PRIMARY KEY (product_id),
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (category_id),
  CONSTRAINT ck_products_price  CHECK (product_price >= 0),
  CONSTRAINT ck_products_status CHECK (product_status IN (0, 1)),
  INDEX ix_products_name (product_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Product catalogue';
