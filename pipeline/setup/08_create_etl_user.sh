#!/bin/bash
# =============================================================================
# 08_create_etl_user.sh - make a READ-ONLY MySQL user for Spark and keep its
# password in Secret Manager (never in code, never in logs).
#
# Why not let Spark use root? "Least privilege": if the ETL password ever
# leaked, it could only READ the data - never change or delete it.
#
# Needs the Auth Proxy running in another tab (same as 07).
# Safe to re-run: it sets a NEW password and stores it as a new secret version.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

echo "==> Checking that MySQL is reachable through the Auth Proxy..."
# 2>&1 keeps MySQL's own error message, so we can show it if the login fails.
if ! MYSQL_ERROR=$(mysql -e "SELECT 1" 2>&1); then
    echo "ERROR: Cannot reach MySQL. Its message was:"
    echo "$MYSQL_ERROR"
    echo "Check, in this order:"
    echo "  1. the proxy runs in another Cloud Shell tab:"
    echo "       cloud-sql-proxy $PROJECT_ID:$REGION:$SQL_INSTANCE"
    echo "  2. ~/.my.cnf exists and holds the right password (guide, chapter 5)"
    echo "  3. Cloud SQL is running (gcloud sql instances describe $SQL_INSTANCE)"
    exit 1
fi

ETL_PASSWORD=$(openssl rand -base64 18)

echo "==> MySQL user '$ETL_USER' with SELECT permission only..."
mysql -e "
    CREATE USER IF NOT EXISTS '$ETL_USER'@'%' IDENTIFIED BY '$ETL_PASSWORD';
    ALTER USER '$ETL_USER'@'%' IDENTIFIED BY '$ETL_PASSWORD';
    GRANT SELECT ON $DB_NAME.* TO '$ETL_USER'@'%';"

echo "==> Secret '$SECRET_NAME' in Secret Manager..."
if ! gcloud secrets describe "$SECRET_NAME" >/dev/null 2>&1; then
    gcloud secrets create "$SECRET_NAME" --replication-policy=automatic
fi
# --data-file=- means "read the secret value from the pipe", so the password
# never appears as a command-line argument.
printf '%s' "$ETL_PASSWORD" | gcloud secrets versions add "$SECRET_NAME" --data-file=-

echo "==> Letting $SPARK_SA read this one secret (and no other)..."
gcloud secrets add-iam-policy-binding "$SECRET_NAME" --format=none \
    --member="serviceAccount:$SPARK_SA_EMAIL" --role="roles/secretmanager.secretAccessor"

echo "==> Done. Grants of '$ETL_USER':"
mysql -e "SHOW GRANTS FOR '$ETL_USER'@'%';"
