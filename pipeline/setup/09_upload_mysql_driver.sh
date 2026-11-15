#!/bin/bash
# =============================================================================
# 09_upload_mysql_driver.sh - put the MySQL JDBC driver (a .jar file) in the
# bucket.
#
# Spark talks to databases through JDBC drivers. Runtime 3.0 does not include
# the MySQL one, and the Spark machines have no internet access, so they
# cannot download it themselves. They CAN read the bucket, so we put it there.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

JAR_FILE="mysql-connector-j-${MYSQL_JAR_VERSION}.jar"
MAVEN_URL="https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_JAR_VERSION}/${JAR_FILE}"

echo "==> MySQL Connector/J $MYSQL_JAR_VERSION -> $MYSQL_JAR"
if gcloud storage objects describe "$MYSQL_JAR" >/dev/null 2>&1; then
    echo "    already in the bucket - skipping."
else
    echo "    downloading from Maven Central..."
    # -f: fail on HTTP errors (e.g. a wrong version number) instead of
    #     saving an error page as the .jar
    curl -fsSL -o "/tmp/$JAR_FILE" "$MAVEN_URL"
    gcloud storage cp "/tmp/$JAR_FILE" "$MYSQL_JAR"
fi

echo "==> Done:"
gcloud storage ls -l "$MYSQL_JAR"
