-- =============================================================================
-- 04_predict.sql - score every order the model has never seen and save the
-- results for the dashboard (table dataco_reporting.late_delivery_risk).
--
-- ML.PREDICT returns the input columns plus:
--   predicted_late        the model's answer: 1 = late, 0 = not late
--   predicted_late_probs  a list of (label, prob) pairs, one per answer, e.g.
--                         [(1, 0.83), (0, 0.17)]; we keep the prob of label 1
--
-- The logistic regression is used because on this data it scored at least
-- as well as the others (see 03_evaluate_models.sql and guide 10.6) and is
-- the simplest model that gives a probability for each shipment.
-- To use the boosted trees instead,
-- change late_delivery_logreg to late_delivery_boosted below.
--
-- We score the 'test' rows (orders from 2017-07-01): orders the model has
-- never seen. Their real outcome is known too, so the dashboard can compare
-- prediction and reality.
-- Nothing re-runs this by itself: run ml/train_model.sh again when new data
-- has been loaded and you want fresh predictions.
-- =============================================================================
CREATE OR REPLACE TABLE dataco_reporting.late_delivery_risk AS
SELECT
  shipment_id,
  order_id,
  order_date,
  shipping_mode,
  market AS market_name,
  region AS region_name,
  customer_segment,
  (SELECT p.prob FROM UNNEST(predicted_late_probs) AS p WHERE p.label = 1) AS late_probability,
  predicted_late = 1 AS predicted_late,
  late = 1 AS actually_late,
  CURRENT_TIMESTAMP() AS scored_at
FROM ML.PREDICT(MODEL dataco_dw.late_delivery_logreg, (
  SELECT *
  FROM dataco_dw.v_shipment_features
  WHERE data_split = 'test'));
