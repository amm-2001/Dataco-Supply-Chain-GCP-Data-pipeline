#!/bin/bash
# =============================================================================
# 04_iam.sh - make the 3 robot identities (service accounts) and give each
# one ONLY the project-level permissions (roles) it needs.
#
#   spark-etl-sa  runs the Spark jobs
#   workflow-sa   runs the scheduled workflow, which starts the Spark jobs
#   scheduler-sa  lets Cloud Scheduler start the workflow every night
#
# Permissions on ONE bucket, ONE secret or ONE dataset are granted later, in
# the script that creates that bucket (05), secret (08) or dataset (10).
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

echo "==> Service account '$SPARK_SA'..."
if ! gcloud iam service-accounts describe "$SPARK_SA_EMAIL" >/dev/null 2>&1; then
    gcloud iam service-accounts create "$SPARK_SA" --display-name="Runs the DataCo Spark jobs"
fi

echo "==> Service account '$WORKFLOW_SA'..."
if ! gcloud iam service-accounts describe "$WORKFLOW_SA_EMAIL" >/dev/null 2>&1; then
    gcloud iam service-accounts create "$WORKFLOW_SA" --display-name="Runs the DataCo workflow"
fi

echo "==> Service account '$SCHEDULER_SA'..."
if ! gcloud iam service-accounts describe "$SCHEDULER_SA_EMAIL" >/dev/null 2>&1; then
    gcloud iam service-accounts create "$SCHEDULER_SA" --display-name="Triggers the DataCo workflow"
fi

# A brand-new service account can take a few seconds to become visible to IAM.
echo "==> Waiting 15 seconds for new accounts to become visible..."
sleep 15

# add-iam-policy-binding is safe to repeat: granting a role twice changes nothing.
# --condition=None means "no time/resource conditions", --format=none hides the
# long policy printout.
echo "==> Roles for $SPARK_SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --format=none \
    --member="serviceAccount:$SPARK_SA_EMAIL" --role="roles/dataproc.worker"     # run as a Spark node
gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --format=none \
    --member="serviceAccount:$SPARK_SA_EMAIL" --role="roles/bigquery.jobUser"    # run BigQuery queries

echo "==> Roles for $WORKFLOW_SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --format=none \
    --member="serviceAccount:$WORKFLOW_SA_EMAIL" --role="roles/dataproc.serverlessEditor"  # submit Spark batches
gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --format=none \
    --member="serviceAccount:$WORKFLOW_SA_EMAIL" --role="roles/bigquery.jobUser"   # run the quality checks
gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --format=none \
    --member="serviceAccount:$WORKFLOW_SA_EMAIL" --role="roles/logging.logWriter"  # write workflow logs
gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --format=none \
    --member="serviceAccount:$WORKFLOW_SA_EMAIL" --role="roles/cloudsql.viewer"    # check Cloud SQL is on
# The workflow starts batches that run AS spark-etl-sa, so it must be allowed
# to "act as" that account (and only that one).
gcloud iam service-accounts add-iam-policy-binding "$SPARK_SA_EMAIL" --format=none \
    --member="serviceAccount:$WORKFLOW_SA_EMAIL" --role="roles/iam.serviceAccountUser"

echo "==> Roles for $SCHEDULER_SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --format=none \
    --member="serviceAccount:$SCHEDULER_SA_EMAIL" --role="roles/workflows.invoker"  # start the workflow

echo "==> IAM ready. Project roles held by the three accounts:"
gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --filter="bindings.members~dataco|etl-sa|workflow-sa|scheduler-sa" \
    --format="table(bindings.members, bindings.role)"
