-- =============================================================================
-- 02_train_models.sql - train two models on the same 'train' rows (chapter 10).
--
--   late_delivery_logreg   logistic regression
--   late_delivery_boosted  boosted trees (XGBoost)
--
-- Both read ONLY the rows with data_split = 'train' (orders before 2017-07-01).
-- The 'test' rows are not here at all: 03_evaluate_models.sql uses them for
-- the final exam, so the score shows how the model does on unseen orders.
--
-- OPTIONS:
--   MODEL_TYPE         which kind of model to train
--   INPUT_LABEL_COLS   the column to predict
--   DATA_SPLIT_METHOD  NO_SPLIT = learn from every row given here. Without it,
--                      BigQuery would quietly hold back some training rows
--                      for its own checks, and you would not know which ones.
-- Every other column in the SELECT is a feature.
-- =============================================================================
CREATE OR REPLACE MODEL dataco_dw.late_delivery_logreg
OPTIONS (
  MODEL_TYPE = 'LOGISTIC_REG',
  INPUT_LABEL_COLS = ['late'],
  DATA_SPLIT_METHOD = 'NO_SPLIT'
) AS
SELECT
  shipping_mode,
  market,
  region,
  customer_segment,
  payment_type,
  order_weekday,
  order_month,
  line_count,
  total_quantity,
  order_net_sales,
  late
FROM dataco_dw.v_shipment_features
WHERE data_split = 'train';

CREATE OR REPLACE MODEL dataco_dw.late_delivery_boosted
OPTIONS (
  MODEL_TYPE = 'BOOSTED_TREE_CLASSIFIER',
  INPUT_LABEL_COLS = ['late'],
  DATA_SPLIT_METHOD = 'NO_SPLIT'
) AS
SELECT
  shipping_mode,
  market,
  region,
  customer_segment,
  payment_type,
  order_weekday,
  order_month,
  line_count,
  total_quantity,
  order_net_sales,
  late
FROM dataco_dw.v_shipment_features
WHERE data_split = 'train';
