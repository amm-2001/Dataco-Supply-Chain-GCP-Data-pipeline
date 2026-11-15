#!/bin/bash
# =============================================================================
# run_pipeline.sh - run the whole pipeline once, by hand.
#
#   bash run_pipeline.sh                  full load: copy every MySQL row again
#   bash run_pipeline.sh --incremental    copy only the rows that are new
#
#   1. upload the two jobs to the bucket
#   2. Job 1: MySQL  -> Parquet files in the bucket
#   3. Job 2: Parquet -> star schema in BigQuery
#   4. run the data quality checks in BigQuery
# =============================================================================
set -e   # stop at the first command that fails
# shellcheck source=config.sh
source "$(dirname "$0")/config.sh"
cd "$(dirname "$0")"   # so the paths below (jobs/, bigquery/, tests/) work from anywhere

echo "==> 1. Uploading the jobs to gs://$BUCKET/code/ ..."
gcloud storage cp jobs/*.py "gs://$BUCKET/code/"

# Everything after the lone "--" is passed to the Python job as its arguments.
# "$@" = whatever you typed after run_pipeline.sh (nothing, or --incremental):
# it changes only what Job 1 copies. Job 2 always rebuilds from the whole lake.
echo "==> 2. Job 1: MySQL -> Parquet (about 3-5 minutes)..."
gcloud dataproc batches submit pyspark "gs://$BUCKET/code/extract_mysql_to_gcs.py" \
    --region="$REGION" \
    --version="$SPARK_RUNTIME" \
    --subnet="$SUBNET" \
    --service-account="$SPARK_SA_EMAIL" \
    --properties="$SPARK_PROPERTIES" \
    --jars="$MYSQL_JAR" \
    -- --project="$PROJECT_ID" --bucket="$BUCKET" --mysql-host="$MYSQL_HOST" "$@"

echo "==> 3. Job 2: Parquet -> BigQuery (about 3-5 minutes)..."
gcloud dataproc batches submit pyspark "gs://$BUCKET/code/transform_to_warehouse.py" \
    --region="$REGION" \
    --version="$SPARK_RUNTIME" \
    --subnet="$SUBNET" \
    --service-account="$SPARK_SA_EMAIL" \
    --properties="$SPARK_PROPERTIES" \
    -- --project="$PROJECT_ID" --bucket="$BUCKET"

echo "==> 4. Data quality checks in BigQuery..."
bq query --use_legacy_sql=false --location="$BQ_LOCATION" < tests/data_quality_checks.sql

echo "==> Pipeline finished successfully."
