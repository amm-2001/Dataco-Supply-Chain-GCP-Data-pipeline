#!/bin/bash
# =============================================================================
# 06_cloud_sql.sh - create the MySQL 8.4 server (Cloud SQL) and the empty
# database dataco_supply_chain. Creating the instance takes 5-10 minutes.
#
# The instance gets TWO addresses:
#   private IP - inside dataco-vpc; Spark connects here (never leaves Google)
#   public IP  - with NO allowed networks, so nobody can connect directly;
#                only the Cloud SQL Auth Proxy (used from Cloud Shell) can.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

PASSWORD_FILE="$HOME/.dataco_root_password"

echo "==> Cloud SQL instance '$SQL_INSTANCE' (MySQL 8.4, $SQL_TIER)..."
if ! gcloud sql instances describe "$SQL_INSTANCE" >/dev/null 2>&1; then
    # A random 24-character password, saved in a file only you can read
    # (umask 077 = new files are private to you).
    umask 077
    openssl rand -base64 18 > "$PASSWORD_FILE"
    echo "    Root password saved in $PASSWORD_FILE (view it with: cat $PASSWORD_FILE)"

    gcloud sql instances create "$SQL_INSTANCE" \
        --database-version=MYSQL_8_4 \
        --edition=ENTERPRISE \
        --tier="$SQL_TIER" \
        --region="$REGION" \
        --availability-type=ZONAL \
        --storage-type=SSD \
        --storage-size=10 \
        --network="projects/$PROJECT_ID/global/networks/$NETWORK" \
        --assign-ip \
        --no-backup \
        --root-password="$(cat "$PASSWORD_FILE")"
else
    echo "    already exists - skipping."
fi

# Creating an instance can take longer than gcloud is willing to wait. If this
# script is re-run, the instance "exists" but may still be starting, so wait
# until its state is RUNNABLE before creating the database.
echo "==> Waiting until the instance is RUNNABLE..."
STATE=""
until [ "$STATE" = "RUNNABLE" ]; do
    STATE=$(gcloud sql instances describe "$SQL_INSTANCE" --format="value(state)")
    if [ "$STATE" = "FAILED" ] || [ "$STATE" = "SUSPENDED" ]; then
        echo "ERROR: the instance is $STATE. Check Cloud SQL in the console."
        exit 1
    fi
    if [ "$STATE" != "RUNNABLE" ]; then
        echo "    state is $STATE - checking again in 30 seconds..."
        sleep 30
    fi
done

echo "==> Database '$DB_NAME' (utf8mb4, same settings as schema/00_create_database.sql)..."
if ! gcloud sql databases describe "$DB_NAME" --instance="$SQL_INSTANCE" >/dev/null 2>&1; then
    gcloud sql databases create "$DB_NAME" \
        --instance="$SQL_INSTANCE" \
        --charset=utf8mb4 \
        --collation=utf8mb4_0900_ai_ci
else
    echo "    already exists - skipping."
fi

echo "==> Cloud SQL ready. Its addresses:"
gcloud sql instances describe "$SQL_INSTANCE" \
    --format="table(ipAddresses[].type, ipAddresses[].ipAddress)"
