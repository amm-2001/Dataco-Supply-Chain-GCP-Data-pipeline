#!/bin/bash
# =============================================================================
# 05_storage.sh - make the Cloud Storage bucket and let Spark use it.
#
# The bucket only holds files that ANOTHER Google service must read:
#   code/   the PySpark files (uploaded by run_pipeline.sh every run)
#   jars/   the MySQL JDBC driver
#   raw/    the Parquet copies of the MySQL tables (Job 1 writes them)
# The Spark BigQuery connector also writes short-lived temporary folders
# named ".spark-bigquery-..." while it loads data; a lifecycle rule deletes
# any leftovers after 1 day.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

echo "==> Bucket gs://$BUCKET in $REGION..."
if ! gcloud storage buckets describe "gs://$BUCKET" >/dev/null 2>&1; then
    # Uniform access = permissions are set on the whole bucket, not per file.
    gcloud storage buckets create "gs://$BUCKET" \
        --location="$REGION" \
        --uniform-bucket-level-access
else
    echo "    already exists - skipping."
fi

echo "==> Lifecycle rule: delete leftover connector temp files after 1 day..."
cat > /tmp/dataco-lifecycle.json <<'EOF'
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 1, "matchesPrefix": [".spark-bigquery-"]}
    }
  ]
}
EOF
gcloud storage buckets update "gs://$BUCKET" --lifecycle-file=/tmp/dataco-lifecycle.json

echo "==> Letting $SPARK_SA read and write files in the bucket..."
gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" --format=none \
    --member="serviceAccount:$SPARK_SA_EMAIL" --role="roles/storage.objectUser"

echo "==> Storage ready."
