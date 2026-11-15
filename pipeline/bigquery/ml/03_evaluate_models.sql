-- =============================================================================
-- 03_evaluate_models.sql - the final exam: both models and a simple rule,
-- scored on the 'test' rows (orders from 2017-07-01) that no model has seen.
--
-- One row per contender:
--   accuracy   share of shipments predicted correctly (late or not late)
--   precision  of the shipments predicted LATE, the share that really were
--   recall     of the shipments that really were LATE, the share predicted
--   roc_auc    0.5 = coin toss, 1.0 = perfect; how well the model RANKS
--              late shipments above on-time ones (no single cut-off needed)
-- A model "predicts late" when its probability is 0.5 or more.
--
-- The simple rule "late if First Class or Second Class" needs no model at
-- all. A model is only worth using if it beats that rule.
-- =============================================================================
SELECT
  'logistic regression' AS model,
  ROUND(accuracy, 3) AS accuracy,
  ROUND(precision, 3) AS precision,
  ROUND(recall, 3) AS recall,
  ROUND(roc_auc, 3) AS roc_auc
FROM ML.EVALUATE(MODEL dataco_dw.late_delivery_logreg, (
  SELECT
    shipping_mode, market, region, customer_segment, payment_type,
    order_weekday, order_month, line_count, total_quantity, order_net_sales, late
  FROM dataco_dw.v_shipment_features
  WHERE data_split = 'test'))

UNION ALL

SELECT
  'boosted trees',
  ROUND(accuracy, 3),
  ROUND(precision, 3),
  ROUND(recall, 3),
  ROUND(roc_auc, 3)
FROM ML.EVALUATE(MODEL dataco_dw.late_delivery_boosted, (
  SELECT
    shipping_mode, market, region, customer_segment, payment_type,
    order_weekday, order_month, line_count, total_quantity, order_net_sales, late
  FROM dataco_dw.v_shipment_features
  WHERE data_split = 'test'))

UNION ALL

SELECT
  'simple rule: First or Second Class = late',
  ROUND(AVG(IF(rule_says_late = (late = 1), 1, 0)), 3),
  ROUND(SAFE_DIVIDE(COUNTIF(rule_says_late AND late = 1), COUNTIF(rule_says_late)), 3),
  ROUND(SAFE_DIVIDE(COUNTIF(rule_says_late AND late = 1), COUNTIF(late = 1)), 3),
  NULL  -- a yes/no rule gives no probabilities, so it has no roc_auc
FROM (
  SELECT shipping_mode IN ('First Class', 'Second Class') AS rule_says_late, late
  FROM dataco_dw.v_shipment_features
  WHERE data_split = 'test')

ORDER BY accuracy DESC;
