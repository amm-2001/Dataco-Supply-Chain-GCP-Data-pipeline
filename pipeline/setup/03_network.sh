#!/bin/bash
# =============================================================================
# 03_network.sh - build the private network that Spark and Cloud SQL share.
#
#   dataco-vpc (our own network)
#    ├── spark-subnet 10.10.0.0/24   <- Spark machines get addresses here
#    └── google-managed-services-dataco (a reserved /16 block)
#            └── peered to Google's network, where Cloud SQL gets its
#                private IP. "Peering" joins two networks so they can talk.
#
# Firewall: Spark runtime 3.0 creates its own firewall rules automatically,
# so this script does not add any.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

echo "==> 1/4 VPC network '$NETWORK'..."
if ! gcloud compute networks describe "$NETWORK" >/dev/null 2>&1; then
    # custom = start empty; we decide which subnets exist.
    gcloud compute networks create "$NETWORK" --subnet-mode=custom
else
    echo "    already exists - skipping."
fi

echo "==> 2/4 Subnet '$SUBNET' ($SUBNET_RANGE) in $REGION..."
if ! gcloud compute networks subnets describe "$SUBNET" --region="$REGION" >/dev/null 2>&1; then
    # Private Google Access: machines without a public IP can still reach
    # Cloud Storage, BigQuery and Secret Manager.
    gcloud compute networks subnets create "$SUBNET" \
        --network="$NETWORK" \
        --region="$REGION" \
        --range="$SUBNET_RANGE" \
        --enable-private-ip-google-access
else
    echo "    already exists - skipping."
fi

echo "==> 3/4 Reserved address block '$PSA_RANGE' for Google services..."
if ! gcloud compute addresses describe "$PSA_RANGE" --global >/dev/null 2>&1; then
    gcloud compute addresses create "$PSA_RANGE" \
        --global \
        --purpose=VPC_PEERING \
        --prefix-length=16 \
        --network="$NETWORK"
else
    echo "    already exists - skipping."
fi

echo "==> 4/4 Peering the block with Google's service network (takes ~1 minute)..."
if ! gcloud services vpc-peerings list --network="$NETWORK" \
        --format="value(peering)" | grep -q "servicenetworking"; then
    gcloud services vpc-peerings connect \
        --service=servicenetworking.googleapis.com \
        --ranges="$PSA_RANGE" \
        --network="$NETWORK"
else
    echo "    already connected - skipping."
fi

echo "==> Network ready."
