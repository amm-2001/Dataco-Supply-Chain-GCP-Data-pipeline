-- =============================================================================
-- 01_features_view.sql - the table the model learns from (chapter 10).
--
-- One row per shipment, with:
--   * 10 FEATURES: facts known when the order is placed (mode, market, ...)
--   * the LABEL "late": what the model learns to predict (1 = late, 0 = not)
--   * data_split: 'train' or 'test' - which group the row belongs to
--   * shipment_id, order_id, order_date: to find the row again; NOT features
--
-- THE SPLIT is decided here, once, by the order date:
--   orders before 2017-07-01   -> 'train'  (49,826 rows, 79%): the models learn
--   orders from 2017-07-01     -> 'test'   (13,071 rows, 21%): the final exam
-- Splitting by date copies real life: a model trained on the past is used on
-- future orders, so we test it on months it has never seen.
--
-- Columns only known AFTER delivery (actual_days, delay_days, delivery_status,
-- shipping_date, order_status) are left out on purpose: they would give the
-- answer away ("data leakage") and the model would be useless on new orders.
--
-- Training, evaluating and predicting all read this ONE view, so the model
-- always sees exactly the same columns, computed in exactly the same way.
-- =============================================================================
CREATE OR REPLACE VIEW dataco_dw.v_shipment_features AS
WITH order_lines AS (
  -- A shipment carries a whole order, so summarise the order's lines first.
  SELECT
    order_id,
    ANY_VALUE(payment_type) AS payment_type,
    COUNT(*) AS line_count,
    SUM(quantity) AS total_quantity,
    SUM(net_sales) AS order_net_sales
  FROM dataco_dw.fact_order_items
  GROUP BY order_id
)
SELECT
  s.shipment_id,
  s.order_id,
  s.order_date,
  s.shipping_mode,
  g.market_name AS market,
  g.region_name AS region,
  c.segment_name AS customer_segment,
  o.payment_type,
  d.day_name AS order_weekday,
  d.month_name AS order_month,
  o.line_count,
  o.total_quantity,
  CAST(o.order_net_sales AS FLOAT64) AS order_net_sales,
  IF(s.is_late, 1, 0) AS late,
  IF(s.order_date < DATE '2017-07-01', 'train', 'test') AS data_split
FROM dataco_dw.fact_shipments AS s
JOIN order_lines AS o ON o.order_id = s.order_id
LEFT JOIN dataco_dw.dim_geography AS g ON g.city_id = s.destination_city_id
LEFT JOIN dataco_dw.dim_customer AS c ON c.customer_id = s.customer_id
LEFT JOIN dataco_dw.dim_date AS d ON d.date = s.order_date
-- A cancelled shipment was never delivered, so it is neither late nor on time.
WHERE s.delivery_status != 'Shipping canceled';
