-- =============================================================================
-- 02_create_tables.sql - the star schema in dataco_dw.
--
--   4 dimensions (descriptions)   dim_customer, dim_product, dim_geography, dim_date
--   2 facts (numbers)             fact_order_items  (one row per order line)
--                                 fact_shipments    (one row per shipment)
--
-- Notes
--   * NUMERIC is an exact decimal type: right for money (no rounding errors).
--   * DATETIME = date + time with no time zone (the source has none).
--   * PRIMARY KEY / FOREIGN KEY ... NOT ENFORCED: BigQuery does NOT check
--     them. They document the model and help the query optimizer.
--     Our data quality checks (tests/data_quality_checks.sql) do the checking.
--   * PARTITION BY ... MONTH: each month is stored separately, so a query on
--     2017 only reads (and bills) the 2017 months.
--   * CLUSTER BY: rows inside each month are sorted by these columns, so
--     filters on them read less data.
-- =============================================================================

CREATE TABLE IF NOT EXISTS dataco_dw.dim_customer (
  customer_id   INT64 NOT NULL,
  first_name    STRING,
  last_name     STRING,
  full_name     STRING,
  segment_name  STRING,
  street        STRING,
  city_name     STRING,
  state_name    STRING,
  country_name  STRING,
  zipcode       STRING,
  latitude      FLOAT64,
  longitude     FLOAT64,
  _loaded_at    TIMESTAMP,
  PRIMARY KEY (customer_id) NOT ENFORCED
)
OPTIONS (description = "One row per customer, with segment and address");

CREATE TABLE IF NOT EXISTS dataco_dw.dim_product (
  product_id       INT64 NOT NULL,
  product_name     STRING,
  category_id      INT64,
  category_name    STRING,
  department_id    INT64,
  department_name  STRING,
  product_price    NUMERIC,
  product_status   STRING,
  _loaded_at       TIMESTAMP,
  PRIMARY KEY (product_id) NOT ENFORCED
)
OPTIONS (description = "One row per product, with category and department");

CREATE TABLE IF NOT EXISTS dataco_dw.dim_geography (
  city_id       INT64 NOT NULL,
  city_name     STRING,
  state_name    STRING,
  state_code    STRING,
  country_name  STRING,
  country_iso2  STRING,
  region_name   STRING,
  market_name   STRING,
  _loaded_at    TIMESTAMP,
  PRIMARY KEY (city_id) NOT ENFORCED
)
OPTIONS (description = "One row per city: city > state > country > region > market");

CREATE TABLE IF NOT EXISTS dataco_dw.dim_date (
  date          DATE NOT NULL,
  year          INT64,
  quarter       INT64,
  month         INT64,
  month_name    STRING,
  year_month    STRING,
  day_of_month  INT64,
  day_of_week   INT64,
  day_name      STRING,
  is_weekend    BOOL,
  _loaded_at    TIMESTAMP,
  PRIMARY KEY (date) NOT ENFORCED
)
OPTIONS (description = "One row per calendar day (day_of_week: 1 = Monday)");

CREATE TABLE IF NOT EXISTS dataco_dw.fact_order_items (
  order_item_id        INT64 NOT NULL,
  order_id             INT64 NOT NULL,
  order_date           DATE NOT NULL,
  order_datetime       DATETIME,
  customer_id          INT64,
  product_id           INT64,
  destination_city_id  INT64,
  order_status         STRING,
  payment_type         STRING,
  quantity             INT64,
  unit_price           NUMERIC,
  gross_sales          NUMERIC,
  discount_rate        NUMERIC,
  discount_amount      NUMERIC,
  net_sales            NUMERIC,
  profit_ratio         NUMERIC,
  profit               NUMERIC,
  _loaded_at           TIMESTAMP,
  PRIMARY KEY (order_item_id) NOT ENFORCED,
  FOREIGN KEY (customer_id) REFERENCES dataco_dw.dim_customer (customer_id) NOT ENFORCED,
  FOREIGN KEY (product_id) REFERENCES dataco_dw.dim_product (product_id) NOT ENFORCED,
  FOREIGN KEY (destination_city_id) REFERENCES dataco_dw.dim_geography (city_id) NOT ENFORCED,
  FOREIGN KEY (order_date) REFERENCES dataco_dw.dim_date (date) NOT ENFORCED
)
PARTITION BY DATE_TRUNC(order_date, MONTH)
CLUSTER BY product_id, customer_id
OPTIONS (description = "Sales fact: one row per order line");

CREATE TABLE IF NOT EXISTS dataco_dw.fact_shipments (
  shipment_id          INT64 NOT NULL,
  order_id             INT64 NOT NULL,
  order_date           DATE,
  shipping_date        DATE NOT NULL,
  shipping_datetime    DATETIME,
  customer_id          INT64,
  destination_city_id  INT64,
  shipping_mode        STRING,
  delivery_status      STRING,
  order_status         STRING,
  scheduled_days       INT64,
  actual_days          INT64,
  delay_days           INT64,
  is_late              BOOL,
  _loaded_at           TIMESTAMP,
  PRIMARY KEY (shipment_id) NOT ENFORCED,
  FOREIGN KEY (customer_id) REFERENCES dataco_dw.dim_customer (customer_id) NOT ENFORCED,
  FOREIGN KEY (destination_city_id) REFERENCES dataco_dw.dim_geography (city_id) NOT ENFORCED,
  FOREIGN KEY (order_date) REFERENCES dataco_dw.dim_date (date) NOT ENFORCED,
  FOREIGN KEY (shipping_date) REFERENCES dataco_dw.dim_date (date) NOT ENFORCED
)
PARTITION BY DATE_TRUNC(shipping_date, MONTH)
CLUSTER BY shipping_mode, delivery_status
OPTIONS (description = "Delivery fact: one row per shipment");
