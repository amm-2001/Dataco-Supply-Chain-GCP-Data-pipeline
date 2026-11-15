#!/bin/bash
# The procedure file below is written one line at a time on purpose (easier to
# read than shellcheck's suggested { ...; } >> file form):
# shellcheck disable=SC2129
# =============================================================================
# deploy_workflow.sh - put the pipeline on a schedule (every night at 02:00).
#
#   1. upload the latest code (the workflow reads it from the bucket)
#   2. save the data quality checks in BigQuery as a stored procedure
#   3. deploy the workflow (pipeline_workflow.yaml), running as workflow-sa
#   4. create the Cloud Scheduler job that starts the workflow
#
# Re-run it after changing any job, the workflow or the quality checks.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"
cd "$(dirname "$0")/.."   # work from the pipeline/ folder

echo "==> 1. Uploading the code to gs://$BUCKET/code/ ..."
gcloud storage cp jobs/*.py "gs://$BUCKET/code/"

echo "==> 2. Saving the quality checks as the procedure dataco_dw.run_quality_checks..."
# A procedure is a named, saved block of SQL. We wrap the existing checks file
# in CREATE PROCEDURE ... BEGIN ... END, so the checks live in ONE file only.
PROCEDURE_FILE=/tmp/dataco_quality_procedure.sql
echo "CREATE OR REPLACE PROCEDURE dataco_dw.run_quality_checks()" > "$PROCEDURE_FILE"
echo "BEGIN" >> "$PROCEDURE_FILE"
cat tests/data_quality_checks.sql >> "$PROCEDURE_FILE"
echo "END;" >> "$PROCEDURE_FILE"
bq query --use_legacy_sql=false --location="$BQ_LOCATION" < "$PROCEDURE_FILE"

echo "==> 3. Deploying the workflow '$WORKFLOW_NAME'..."
gcloud workflows deploy "$WORKFLOW_NAME" \
    --location="$REGION" \
    --source=workflow/pipeline_workflow.yaml \
    --service-account="$WORKFLOW_SA_EMAIL" \
    --set-env-vars="REGION=$REGION,BUCKET=$BUCKET,SUBNET=$SUBNET,SPARK_SA_EMAIL=$SPARK_SA_EMAIL,SPARK_RUNTIME=$SPARK_RUNTIME,SQL_INSTANCE=$SQL_INSTANCE,MYSQL_JAR=$MYSQL_JAR,MYSQL_HOST=$MYSQL_HOST"

echo "==> 4. Scheduler job '$SCHEDULE_NAME' (every day 02:00 Riyadh time)..."
if ! gcloud scheduler jobs describe "$SCHEDULE_NAME" --location="$REGION" >/dev/null 2>&1; then
    # Cloud Scheduler calls the Workflows API to start a new execution,
    # proving who it is with an OAuth token of scheduler-sa.
    gcloud scheduler jobs create http "$SCHEDULE_NAME" \
        --location="$REGION" \
        --schedule="0 2 * * *" \
        --time-zone="Asia/Riyadh" \
        --uri="https://workflowexecutions.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/workflows/$WORKFLOW_NAME/executions" \
        --http-method=POST \
        --message-body='{}' \
        --oauth-service-account-email="$SCHEDULER_SA_EMAIL"
else
    echo "    already exists - skipping."
fi

echo "==> Done. Run it now (without waiting for 02:00):"
echo "    gcloud workflows run $WORKFLOW_NAME --location=$REGION"
echo "Pause / resume the schedule (do this when you stop / start Cloud SQL):"
echo "    gcloud scheduler jobs pause $SCHEDULE_NAME --location=$REGION"
echo "    gcloud scheduler jobs resume $SCHEDULE_NAME --location=$REGION"
