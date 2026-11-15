#!/bin/bash
# =============================================================================
# 07_load_source_data.sh - build the 17 MySQL tables and load their rows by
# running YOUR SQL files (../schema and ../data) from Cloud Shell.
#
# Before running it you need (see the guide, chapter 5):
#   1. the Cloud SQL Auth Proxy running in ANOTHER Cloud Shell tab:
#        cloud-sql-proxy datacosupplychain-project:us-central1:dataco-mysql
#   2. the file ~/.my.cnf holding host, user and password, so the MySQL client
#      can log in without asking for the password 34 times.
#
# Safe to re-run: it first drops the old tables, so every run starts clean.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

# The folder that holds schema/, data/ and pipeline/ (two levels above setup/).
ROOT_DIR="$(dirname "$0")/../.."

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

echo "==> Removing old tables (if any) so the load starts clean..."
mysql "$DB_NAME" < "$ROOT_DIR/schema/99_drop_all_tables.sql"

# 0[1-9]_*.sql matches 01..09 and 1[0-7]_*.sql matches 10..17, in that order.
# 00_create_database.sql is skipped (06_cloud_sql.sh made the database) and
# 99_drop_all_tables.sql is skipped (it was used just above).
echo "==> Creating the 17 tables..."
for FILE in "$ROOT_DIR"/schema/0[1-9]_*.sql "$ROOT_DIR"/schema/1[0-7]_*.sql; do
    echo "    $(basename "$FILE")"
    mysql "$DB_NAME" < "$FILE"
done

echo "==> Loading the data (order_items is the biggest: ~1 minute)..."
for FILE in "$ROOT_DIR"/data/*.sql; do
    echo "    $(basename "$FILE")"
    mysql "$DB_NAME" < "$FILE"
done

echo "==> Comparing row counts with the numbers in the data files:"
mysql --table "$DB_NAME" < "$(dirname "$0")/../tests/check_source_counts.sql"
