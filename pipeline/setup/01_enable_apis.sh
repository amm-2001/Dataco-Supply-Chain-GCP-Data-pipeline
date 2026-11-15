#!/bin/bash
# =============================================================================
# 01_enable_apis.sh - switch on every Google Cloud service this project uses.
#
# A new project has most services OFF. A service is "enabled" by turning on
# its API. Enabling is free; you only pay for the resources you use.
# Safe to re-run: enabling an API that is already on does nothing.
# =============================================================================
set -e   # stop the script at the first command that fails
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

echo "==> Enabling APIs in $PROJECT_ID (the first time can take 1-2 minutes)..."
gcloud services enable \
    compute.googleapis.com \
    servicenetworking.googleapis.com \
    sqladmin.googleapis.com \
    dataproc.googleapis.com \
    dataprocrm.googleapis.com \
    bigquery.googleapis.com \
    storage.googleapis.com \
    secretmanager.googleapis.com \
    workflows.googleapis.com \
    workflowexecutions.googleapis.com \
    cloudscheduler.googleapis.com \
    cloudbilling.googleapis.com \
    billingbudgets.googleapis.com \
    iam.googleapis.com

echo "==> Done. These project APIs are now enabled:"
gcloud services list --enabled --format="value(config.name)" \
    | grep -E "sqladmin|dataproc|bigquery|secretmanager|workflow|scheduler|servicenetworking"
