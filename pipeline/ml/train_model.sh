#!/bin/bash
# =============================================================================
# train_model.sh - chapter 10: train, test and use the late-delivery models.
#
#   1. create the features view, which also splits the rows into
#      'train' and 'test'                (bigquery/ml/01_features_view.sql)
#   2. show how many rows are in each group
#   3. train both models on 'train'       (02_train_models.sql, ~15-20 minutes)
#   4. score them on 'test'               (03_evaluate_models.sql)
#   5. save predictions for the dashboard (04_predict.sql)
#
# Needs the warehouse loaded first (run_pipeline.sh, chapter 9).
# Safe to re-run: every step replaces what the previous run made. Re-run it
# whenever new data has been loaded and you want fresh predictions.
# Run it from Cloud Shell:   bash ~/dataco/pipeline/ml/train_model.sh
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"
cd "$(dirname "$0")/.."   # work from the pipeline/ folder

echo "==> 1. Features view dataco_dw.v_shipment_features..."
bq query --use_legacy_sql=false --location="$BQ_LOCATION" < bigquery/ml/01_features_view.sql

echo "==> 2. The split: rows, dates and late share in each group:"
bq query --use_legacy_sql=false --location="$BQ_LOCATION" "
SELECT data_split, COUNT(*) AS shipments,
       MIN(order_date) AS first_order, MAX(order_date) AS last_order,
       ROUND(AVG(late), 3) AS late_share
FROM dataco_dw.v_shipment_features
GROUP BY data_split
ORDER BY first_order"

echo "==> 3. Training both models on the 'train' rows (about 15-20 minutes)..."
bq query --use_legacy_sql=false --location="$BQ_LOCATION" < bigquery/ml/02_train_models.sql

echo "==> 4. The final exam: both models and the simple rule on the 'test' rows:"
bq query --use_legacy_sql=false --location="$BQ_LOCATION" < bigquery/ml/03_evaluate_models.sql

echo "==> 5. Saving predictions to dataco_reporting.late_delivery_risk..."
bq query --use_legacy_sql=false --location="$BQ_LOCATION" < bigquery/ml/04_predict.sql

echo "==> Done. Next: the dashboard (chapter 11)."
