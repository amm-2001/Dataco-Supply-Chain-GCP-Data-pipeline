#!/bin/bash
# =============================================================================
# cleanup.sh - remove EVERYTHING this project created, so nothing keeps
# costing money. It asks you to type DELETE first.
#
# Order matters: things that use the network must go before the network.
#   scheduler -> workflow -> Cloud SQL -> bucket -> datasets -> secret
#   -> service accounts -> peering + reserved range -> subnet -> network
# Each step checks first, so the script can be re-run if it stops halfway.
# =============================================================================
set -e
# shellcheck source=config.sh
source "$(dirname "$0")/config.sh"

read -r -p "This removes ALL DataCo resources in $PROJECT_ID. Type DELETE to continue: " ANSWER
if [ "$ANSWER" != "DELETE" ]; then
    echo "Nothing removed."
    exit 0
fi

echo "==> Scheduler job..."
if gcloud scheduler jobs describe "$SCHEDULE_NAME" --location="$REGION" >/dev/null 2>&1; then
    gcloud scheduler jobs delete "$SCHEDULE_NAME" --location="$REGION" --quiet
fi

echo "==> Workflow..."
if gcloud workflows describe "$WORKFLOW_NAME" --location="$REGION" >/dev/null 2>&1; then
    gcloud workflows delete "$WORKFLOW_NAME" --location="$REGION" --quiet
fi

echo "==> Cloud SQL instance (takes a few minutes)..."
if gcloud sql instances describe "$SQL_INSTANCE" >/dev/null 2>&1; then
    gcloud sql instances delete "$SQL_INSTANCE" --quiet
fi

echo "==> Bucket and all its files..."
if gcloud storage buckets describe "gs://$BUCKET" >/dev/null 2>&1; then
    gcloud storage rm --recursive "gs://$BUCKET"
fi

echo "==> BigQuery datasets..."
for DATASET in dataco_reporting dataco_dw; do
    if bq show "$PROJECT_ID:$DATASET" >/dev/null 2>&1; then
        bq rm -r -f -d "$PROJECT_ID:$DATASET"   # -r: with its tables, -f: no prompt
    fi
done

echo "==> Secret..."
if gcloud secrets describe "$SECRET_NAME" >/dev/null 2>&1; then
    gcloud secrets delete "$SECRET_NAME" --quiet
fi

echo "==> Service accounts..."
for SA_EMAIL in "$SPARK_SA_EMAIL" "$WORKFLOW_SA_EMAIL" "$SCHEDULER_SA_EMAIL"; do
    if gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1; then
        gcloud iam service-accounts delete "$SA_EMAIL" --quiet
    fi
done

echo "==> Network peering and reserved range..."
# Right after Cloud SQL is deleted, Google often keeps the peering "in use"
# for a while. A failure here is normal: we print advice and carry on.
# (The network pieces left behind cost nothing.)
if gcloud services vpc-peerings list --network="$NETWORK" --format="value(peering)" 2>/dev/null \
        | grep -q "servicenetworking"; then
    if ! gcloud services vpc-peerings delete --network="$NETWORK" \
            --service=servicenetworking.googleapis.com --quiet; then
        echo "    The peering is still in use by Google. Wait 30 minutes and run this script again."
    fi
fi
if gcloud compute addresses describe "$PSA_RANGE" --global >/dev/null 2>&1; then
    if ! gcloud compute addresses delete "$PSA_RANGE" --global --quiet; then
        echo "    The reserved range is still in use. Wait 30 minutes and run this script again."
    fi
fi

echo "==> Subnet and network..."
if gcloud compute networks subnets describe "$SUBNET" --region="$REGION" >/dev/null 2>&1; then
    if ! gcloud compute networks subnets delete "$SUBNET" --region="$REGION" --quiet; then
        echo "    The subnet is still in use. Wait 30 minutes and run this script again."
    fi
fi
if gcloud compute networks describe "$NETWORK" >/dev/null 2>&1; then
    if ! gcloud compute networks delete "$NETWORK" --quiet; then
        echo "The network could not be removed yet (Google may still be releasing"
        echo "Spark firewall rules or Cloud SQL addresses). Wait 30 minutes and run"
        echo "this script again - everything else is already gone."
    fi
fi

echo "==> Cleanup finished. Also delete your local secrets in Cloud Shell:"
echo "    rm ~/.my.cnf ~/.dataco_root_password"
