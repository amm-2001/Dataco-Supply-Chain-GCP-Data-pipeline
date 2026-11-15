-- =============================================================================
-- 03_create_views.sql - two flat views for Looker Studio.
--
-- A view is a saved SELECT: it stores no data, it runs when someone queries it.
-- Looker Studio works best with ONE wide table per chart, so the views do the
-- star-schema joins once, here, in SQL we control.
--
-- LEFT JOIN keeps every fact row even if a dimension row were missing
-- (the data quality checks make sure that never happens).
-- =============================================================================

CREATE OR REPLACE VIEW dataco_reporting.v_sales AS
SELECT
  f.* EXCEPT (_loaded_at),
  -- when (order date)
  d.year,
  d.quarter,
  d.month_name,
  d.year_month,
  d.day_name,
  d.is_weekend,
  -- who
  c.full_name,
  c.segment_name,
  c.country_name AS customer_country,
  -- what
  p.product_name,
  p.category_name,
  p.department_name,
  -- where (destination)
  g.city_name,
  g.state_name,
  g.country_name,
  g.country_iso2,
  g.region_name,
  g.market_name
FROM dataco_dw.fact_order_items AS f
LEFT JOIN dataco_dw.dim_date AS d ON d.date = f.order_date
LEFT JOIN dataco_dw.dim_customer AS c ON c.customer_id = f.customer_id
LEFT JOIN dataco_dw.dim_product AS p ON p.product_id = f.product_id
LEFT JOIN dataco_dw.dim_geography AS g ON g.city_id = f.destination_city_id;

CREATE OR REPLACE VIEW dataco_reporting.v_delivery AS
SELECT
  f.* EXCEPT (_loaded_at),
  -- when (shipping date)
  d.year,
  d.quarter,
  d.month_name,
  d.year_month,
  d.day_name,
  d.is_weekend,
  -- who
  c.segment_name,
  -- where (destination)
  g.city_name,
  g.state_name,
  g.country_name,
  g.country_iso2,
  g.region_name,
  g.market_name
FROM dataco_dw.fact_shipments AS f
LEFT JOIN dataco_dw.dim_date AS d ON d.date = f.shipping_date
LEFT JOIN dataco_dw.dim_customer AS c ON c.customer_id = f.customer_id
LEFT JOIN dataco_dw.dim_geography AS g ON g.city_id = f.destination_city_id;
