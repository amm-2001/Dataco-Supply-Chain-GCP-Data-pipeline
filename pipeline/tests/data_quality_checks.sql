-- =============================================================================
-- data_quality_checks.sql - is the warehouse correct? Run after every load.
--
-- ASSERT (condition) AS 'message' stops the script with that message as soon
-- as a condition is FALSE. So if this file finishes, every check passed.
-- Run:  bq query --use_legacy_sql=false --location=US < tests/data_quality_checks.sql
--
-- What is checked (the keys are NOT ENFORCED by BigQuery, so we enforce here):
--   1. no table is empty
--   2. every primary key is filled in (no NULL) and unique (no duplicates)
--   3. every foreign key in the facts finds its dimension row (no "orphans")
--   4. one shipment per order
--   5. delay_days was computed correctly
--   6. the fact tables are still partitioned
-- =============================================================================

-- 1 + 2. Not empty, primary keys not NULL and unique ---------------------------
ASSERT (SELECT COUNT(*) FROM dataco_dw.dim_customer) > 0 AS 'dim_customer: table is empty';
ASSERT (SELECT COUNTIF(customer_id IS NULL) FROM dataco_dw.dim_customer) = 0 AS 'dim_customer: NULL customer_id';
ASSERT (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM dataco_dw.dim_customer) = 0 AS 'dim_customer: duplicate customer_id';

ASSERT (SELECT COUNT(*) FROM dataco_dw.dim_product) > 0 AS 'dim_product: table is empty';
ASSERT (SELECT COUNTIF(product_id IS NULL) FROM dataco_dw.dim_product) = 0 AS 'dim_product: NULL product_id';
ASSERT (SELECT COUNT(*) - COUNT(DISTINCT product_id) FROM dataco_dw.dim_product) = 0 AS 'dim_product: duplicate product_id';

ASSERT (SELECT COUNT(*) FROM dataco_dw.dim_geography) > 0 AS 'dim_geography: table is empty';
ASSERT (SELECT COUNTIF(city_id IS NULL) FROM dataco_dw.dim_geography) = 0 AS 'dim_geography: NULL city_id';
ASSERT (SELECT COUNT(*) - COUNT(DISTINCT city_id) FROM dataco_dw.dim_geography) = 0 AS 'dim_geography: duplicate city_id';

ASSERT (SELECT COUNT(*) FROM dataco_dw.dim_date) > 0 AS 'dim_date: table is empty';
ASSERT (SELECT COUNTIF(date IS NULL) FROM dataco_dw.dim_date) = 0 AS 'dim_date: NULL date';
ASSERT (SELECT COUNT(*) - COUNT(DISTINCT date) FROM dataco_dw.dim_date) = 0 AS 'dim_date: duplicate date';

ASSERT (SELECT COUNT(*) FROM dataco_dw.fact_order_items) > 0 AS 'fact_order_items: table is empty';
ASSERT (SELECT COUNTIF(order_item_id IS NULL) FROM dataco_dw.fact_order_items) = 0 AS 'fact_order_items: NULL order_item_id';
ASSERT (SELECT COUNT(*) - COUNT(DISTINCT order_item_id) FROM dataco_dw.fact_order_items) = 0 AS 'fact_order_items: duplicate order_item_id';

ASSERT (SELECT COUNT(*) FROM dataco_dw.fact_shipments) > 0 AS 'fact_shipments: table is empty';
ASSERT (SELECT COUNTIF(shipment_id IS NULL) FROM dataco_dw.fact_shipments) = 0 AS 'fact_shipments: NULL shipment_id';
ASSERT (SELECT COUNT(*) - COUNT(DISTINCT shipment_id) FROM dataco_dw.fact_shipments) = 0 AS 'fact_shipments: duplicate shipment_id';

-- 3. No orphan foreign keys ---------------------------------------------------
-- A LEFT JOIN keeps every fact row; where no dimension row matched, the
-- dimension columns are NULL. Counting those rows counts the orphans.
ASSERT (
  SELECT COUNT(*) FROM dataco_dw.fact_order_items AS f
  LEFT JOIN dataco_dw.dim_customer AS c ON c.customer_id = f.customer_id
  WHERE c.customer_id IS NULL
) = 0 AS 'fact_order_items: customer_id not found in dim_customer';
ASSERT (
  SELECT COUNT(*) FROM dataco_dw.fact_order_items AS f
  LEFT JOIN dataco_dw.dim_product AS p ON p.product_id = f.product_id
  WHERE p.product_id IS NULL
) = 0 AS 'fact_order_items: product_id not found in dim_product';
ASSERT (
  SELECT COUNT(*) FROM dataco_dw.fact_order_items AS f
  LEFT JOIN dataco_dw.dim_geography AS g ON g.city_id = f.destination_city_id
  WHERE g.city_id IS NULL
) = 0 AS 'fact_order_items: destination_city_id not found in dim_geography';
ASSERT (
  SELECT COUNT(*) FROM dataco_dw.fact_order_items AS f
  LEFT JOIN dataco_dw.dim_date AS d ON d.date = f.order_date
  WHERE d.date IS NULL
) = 0 AS 'fact_order_items: order_date not found in dim_date';

ASSERT (
  SELECT COUNT(*) FROM dataco_dw.fact_shipments AS f
  LEFT JOIN dataco_dw.dim_customer AS c ON c.customer_id = f.customer_id
  WHERE c.customer_id IS NULL
) = 0 AS 'fact_shipments: customer_id not found in dim_customer';
ASSERT (
  SELECT COUNT(*) FROM dataco_dw.fact_shipments AS f
  LEFT JOIN dataco_dw.dim_geography AS g ON g.city_id = f.destination_city_id
  WHERE g.city_id IS NULL
) = 0 AS 'fact_shipments: destination_city_id not found in dim_geography';
ASSERT (
  SELECT COUNT(*) FROM dataco_dw.fact_shipments AS f
  LEFT JOIN dataco_dw.dim_date AS d ON d.date = f.order_date
  WHERE d.date IS NULL
) = 0 AS 'fact_shipments: order_date not found in dim_date';
ASSERT (
  SELECT COUNT(*) FROM dataco_dw.fact_shipments AS f
  LEFT JOIN dataco_dw.dim_date AS d ON d.date = f.shipping_date
  WHERE d.date IS NULL
) = 0 AS 'fact_shipments: shipping_date not found in dim_date';

-- 4. One shipment per order -----------------------------------------------------
ASSERT (SELECT COUNT(*) FROM dataco_dw.fact_shipments)
     = (SELECT COUNT(DISTINCT order_id) FROM dataco_dw.fact_order_items)
  AS 'fact_shipments: number of shipments differs from number of orders';

-- 5. delay_days = actual - scheduled ---------------------------------------------
ASSERT (
  SELECT COUNTIF(delay_days != actual_days - scheduled_days) FROM dataco_dw.fact_shipments
) = 0 AS 'fact_shipments: delay_days is not actual_days - scheduled_days';

-- 6. Partitioning still in place -------------------------------------------------
ASSERT (
  SELECT COUNT(*) FROM dataco_dw.INFORMATION_SCHEMA.COLUMNS
  WHERE is_partitioning_column = 'YES'
    AND ((table_name = 'fact_order_items' AND column_name = 'order_date')
      OR (table_name = 'fact_shipments' AND column_name = 'shipping_date'))
) = 2 AS 'fact_order_items / fact_shipments: partitioning is missing';

SELECT 'All data quality checks passed' AS result;
