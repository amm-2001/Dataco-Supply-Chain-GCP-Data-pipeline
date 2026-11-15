#!/bin/bash
# =============================================================================
# 10_bigquery_tables.sh - build the BigQuery warehouse (datasets, tables,
# views) and give the service accounts access to those datasets only.
#
# The SQL lives in ../bigquery/*.sql so you can read and change it as SQL.
# Safe to re-run: the SQL uses IF NOT EXISTS / CREATE OR REPLACE.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

SQL_DIR="$(dirname "$0")/../bigquery"

echo "==> Running the warehouse SQL files..."
for SQL_FILE in 01_create_datasets.sql 02_create_tables.sql 03_create_views.sql; do
    echo "    $SQL_FILE"
    # --use_legacy_sql=false = use standard GoogleSQL (the SQL you know).
    bq query --use_legacy_sql=false --location="$BQ_LOCATION" < "$SQL_DIR/$SQL_FILE"
done

echo "==> Dataset permissions (BigQuery GRANT statements)..."
# Spark writes the star schema into dw.
# The workflow only READS dw (to run the quality checks).
bq query --use_legacy_sql=false --location="$BQ_LOCATION" "
GRANT \`roles/bigquery.dataEditor\` ON SCHEMA dataco_dw TO 'serviceAccount:$SPARK_SA_EMAIL';
GRANT \`roles/bigquery.dataEditor\` ON SCHEMA dataco_reporting TO 'serviceAccount:$SPARK_SA_EMAIL';
GRANT \`roles/bigquery.dataViewer\` ON SCHEMA dataco_dw TO 'serviceAccount:$WORKFLOW_SA_EMAIL';
"

echo "==> Warehouse ready. Tables in dataco_dw:"
bq ls "$PROJECT_ID:dataco_dw"
