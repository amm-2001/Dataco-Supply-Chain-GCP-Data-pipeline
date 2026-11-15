#!/bin/bash
# The variables below are used by OTHER scripts, so tell the shellcheck
# linter not to warn that they look unused in this file.
# shellcheck disable=SC2034
# =============================================================================
# config.sh - every name used by this project, in ONE place.
#
# Every other script starts with:   source "$(dirname "$0")/config.sh"
# "source" runs this file inside the calling script, so the variables below
# become available there. Change a value here and every script follows.
# =============================================================================

# --- Project and location ----------------------------------------------------
PROJECT_ID="datacosupplychain-project"
REGION="us-central1"          # where Cloud SQL, Spark and the bucket live
BQ_LOCATION="US"              # BigQuery multi-region that contains us-central1

# --- Cloud Storage -------------------------------------------------------------
BUCKET="${PROJECT_ID}-dataco" # bucket names are global, so we prefix the project

# --- Network -------------------------------------------------------------------
NETWORK="dataco-vpc"
SUBNET="spark-subnet"
SUBNET_RANGE="10.10.0.0/24"   # 256 private addresses for the Spark machines
PSA_RANGE="google-managed-services-dataco"  # addresses reserved for Cloud SQL

# --- Cloud SQL (the MySQL source) ---------------------------------------------
SQL_INSTANCE="dataco-mysql"
SQL_TIER="db-g1-small"        # smallest shared-core machine with 1.7 GB RAM
DB_NAME="dataco_supply_chain"
ETL_USER="etl_reader"         # read-only MySQL user that Spark logs in with
SECRET_NAME="mysql-etl-reader-password"
# Cloud SQL's PRIVATE IP address, the one Spark connects to. After chapter 5,
# replace the placeholder with the PRIVATE address that 06_cloud_sql.sh prints.
MYSQL_HOST="10.80.0.3"

# --- Service accounts (robot identities) --------------------------------------
SPARK_SA="spark-etl-sa"       # runs the Spark jobs
WORKFLOW_SA="workflow-sa"     # runs the scheduled workflow
SCHEDULER_SA="scheduler-sa"   # lets Cloud Scheduler start the workflow
SPARK_SA_EMAIL="${SPARK_SA}@${PROJECT_ID}.iam.gserviceaccount.com"
WORKFLOW_SA_EMAIL="${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com"
SCHEDULER_SA_EMAIL="${SCHEDULER_SA}@${PROJECT_ID}.iam.gserviceaccount.com"

# --- Spark ---------------------------------------------------------------------
SPARK_RUNTIME="3.0"           # serverless runtime 3.0 = Spark 4.0, Python 3.12
# Newest GA MySQL Connector/J (released 2026-10-21), checked on 2026-11-06 at
# https://dev.mysql.com/doc/relnotes/connector-j/en/news-26-x.html
MYSQL_JAR_VERSION="26.10.0"
MYSQL_JAR="gs://${BUCKET}/jars/mysql-connector-j-${MYSQL_JAR_VERSION}.jar"
# The Spark settings every batch uses: 1 driver + 2 executors, 4 CPUs each.
SPARK_PROPERTIES="spark.driver.cores=4,spark.executor.cores=4,spark.executor.instances=2,spark.dynamicAllocation.maxExecutors=2,spark.sql.session.timeZone=UTC"

# --- Orchestration -------------------------------------------------------------
WORKFLOW_NAME="dataco-pipeline"
SCHEDULE_NAME="daily-dataco-pipeline"

# Make every gcloud / bq command below talk to THIS project by default.
gcloud config set project "$PROJECT_ID" --quiet
