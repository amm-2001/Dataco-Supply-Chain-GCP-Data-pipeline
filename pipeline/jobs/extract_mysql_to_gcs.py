"""
extract_mysql_to_gcs.py - JOB 1: copy the MySQL tables into Cloud Storage.

Each table is saved as Parquet files in its own folder (the "lake"):
    MySQL table "orders"  ->  gs://<bucket>/raw/orders/

Full load (the default): copy every table completely, replacing the old copy.
Incremental load (--incremental): for every table, copy only the rows that
are not in the lake yet, and add them to it.
"""
import argparse

from pyspark.sql import SparkSession

# --- Settings that never change ------------------------------------------------
DATABASE = "dataco_supply_chain"
MYSQL_USER = "etl_reader"                    # the read-only user from chapter 5
SECRET_NAME = "mysql-etl-reader-password"    # its password, in Secret Manager

# The 17 tables (same order as the schema/ files) and the id column of each.
# MySQL numbers new rows with AUTO_INCREMENT, so a new row always gets a bigger id.
TABLES = {
    "markets": "market_id",
    "regions": "region_id",
    "countries": "country_id",
    "states": "state_id",
    "cities": "city_id",
    "departments": "department_id",
    "categories": "category_id",
    "products": "product_id",
    "customer_segments": "segment_id",
    "customers": "customer_id",
    "payment_types": "payment_type_id",
    "order_statuses": "order_status_id",
    "shipping_modes": "shipping_mode_id",
    "delivery_statuses": "delivery_status_id",
    "orders": "order_id",
    "shipments": "shipment_id",
    "order_items": "order_item_id",
}

# --- Settings given on the command line (they change between projects/runs) ---
parser = argparse.ArgumentParser(description="Job 1: copy MySQL tables to Parquet")
parser.add_argument("--project", required=True, help="Google Cloud project id")
parser.add_argument("--bucket", required=True, help="bucket name, without gs://")
parser.add_argument("--mysql-host", required=True, help="private IP of Cloud SQL")
parser.add_argument("--incremental", action="store_true",
                    help="copy only the rows that are not in the lake yet")


def main():
    args = parser.parse_args()
    spark = SparkSession.builder.appName("dataco-extract").getOrCreate()

    # Imported here (not at the top) so the tests can run without this library.
    from google.cloud import secretmanager

    # 1. Read the MySQL password from Secret Manager.
    secrets = secretmanager.SecretManagerServiceClient()
    secret_path = f"projects/{args.project}/secrets/{SECRET_NAME}/versions/latest"
    password = secrets.access_secret_version(name=secret_path).payload.data.decode("utf-8")

    # 2. Copy each table from MySQL to the lake.
    mysql_url = f"jdbc:mysql://{args.mysql_host}:3306/{DATABASE}?sslMode=REQUIRED"
    for table, id_column in TABLES.items():
        folder = f"gs://{args.bucket}/raw/{table}/"

        if args.incremental:
            # The biggest id already in the lake; anything above it is new.
            last_id = spark.read.parquet(folder).selectExpr(f"MAX({id_column})").first()[0]
            query = f"SELECT * FROM {table} WHERE {id_column} > {last_id}"
            write_mode = "append"       # add the new rows to the old ones
        else:
            query = f"SELECT * FROM {table}"
            write_mode = "overwrite"    # replace the old copy completely

        df = (
            spark.read.format("jdbc")
            .option("url", mysql_url)
            .option("driver", "com.mysql.cj.jdbc.Driver")   # the class inside the --jars file
            .option("user", MYSQL_USER)
            .option("password", password)
            .option("query", query)
            .option("preferTimestampNTZ", "true")   # DATETIME stays DATETIME
            .load()
        )
        df.write.mode(write_mode).parquet(folder)
        print(f"{table}: {df.count()} rows copied")

    spark.stop()


if __name__ == "__main__":
    main()
