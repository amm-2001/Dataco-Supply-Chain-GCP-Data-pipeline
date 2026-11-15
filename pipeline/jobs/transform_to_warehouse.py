"""
transform_to_warehouse.py - JOB 2: build the star schema in BigQuery.

1. Each raw table that Job 1 saved gets a name ("view") that SQL can use.
2. Each warehouse table is built by ONE SQL query (written below).
3. Each table in the dataco_dw dataset is emptied, then filled again.

Job 2 always rebuilds the whole warehouse from the lake. After an incremental
Job 1 the lake still holds every row (old + new), so the result is complete.
"""
import argparse

from pyspark.sql import SparkSession

# --- Settings given on the command line ---------------------------------------
parser = argparse.ArgumentParser(description="Job 2: build the star schema in BigQuery")
parser.add_argument("--project", required=True, help="Google Cloud project id")
parser.add_argument("--bucket", required=True, help="bucket name, without gs://")

# The raw tables Job 1 saved (the same list as in Job 1).
RAW_TABLES = [
    "markets", "regions", "countries", "states", "cities",
    "departments", "categories", "products",
    "customer_segments", "customers",
    "payment_types", "order_statuses", "shipping_modes", "delivery_statuses",
    "orders", "shipments", "order_items",
]

# --- One SQL query per warehouse table ----------------------------------------
# The column names and order match bigquery/02_create_tables.sql.

# One row per customer, with the segment name and the address spelled out.
DIM_CUSTOMER_SQL = """
    SELECT
        cu.customer_id,
        cu.first_name,
        cu.last_name,
        concat_ws(' ', cu.first_name, cu.last_name) AS full_name,  -- skips a missing last name
        sg.segment_name,
        cu.street,
        ci.city_name,
        st.state_name,
        co.country_name,
        cu.zipcode,
        CAST(cu.latitude AS DOUBLE)  AS latitude,   -- a map coordinate, not money
        CAST(cu.longitude AS DOUBLE) AS longitude,
        current_timestamp() AS _loaded_at
    FROM customers cu
    JOIN customer_segments sg ON sg.segment_id = cu.segment_id
    JOIN cities ci            ON ci.city_id    = cu.city_id
    JOIN states st            ON st.state_id   = ci.state_id
    JOIN countries co         ON co.country_id = st.country_id
"""

# One row per product, with its category and department names.
DIM_PRODUCT_SQL = """
    SELECT
        p.product_id,
        p.product_name,
        c.category_id,
        c.category_name,
        d.department_id,
        d.department_name,
        p.product_price,
        CASE WHEN p.product_status = 0 THEN 'Available'
             ELSE 'Not available' END AS product_status,  -- words instead of 0/1
        current_timestamp() AS _loaded_at
    FROM products p
    JOIN categories c  ON c.category_id   = p.category_id
    JOIN departments d ON d.department_id = c.department_id
"""

# One row per city, with its state, country, sales region and market.
# Some states have no region: LEFT JOIN keeps them, COALESCE writes 'Unknown'.
DIM_GEOGRAPHY_SQL = """
    SELECT
        ci.city_id,
        ci.city_name,
        st.state_name,
        st.state_code,
        co.country_name,
        co.iso_alpha2 AS country_iso2,
        COALESCE(r.region_name, 'Unknown') AS region_name,
        COALESCE(m.market_name, 'Unknown') AS market_name,
        current_timestamp() AS _loaded_at
    FROM cities ci
    JOIN states st         ON st.state_id   = ci.state_id
    JOIN countries co      ON co.country_id = st.country_id
    LEFT JOIN regions r    ON r.region_id   = st.region_id
    LEFT JOIN markets m    ON m.market_id   = r.market_id
"""

# One row per day from 2015-01-01 to 2030-12-31: a calendar for every order
# we will ever load. sequence() makes ONE list of dates, explode() turns the
# list into one ROW per date.
DIM_DATE_SQL = """
    WITH days AS (
        SELECT explode(sequence(DATE'2015-01-01', DATE'2030-12-31')) AS date
    )
    SELECT
        date,
        year(date)                   AS year,
        quarter(date)                AS quarter,
        month(date)                  AS month,
        date_format(date, 'MMMM')    AS month_name,    -- January
        date_format(date, 'yyyy-MM') AS year_month,    -- 2015-01
        dayofmonth(date)             AS day_of_month,
        weekday(date) + 1            AS day_of_week,   -- Monday = 1 ... Sunday = 7
        date_format(date, 'EEEE')    AS day_name,      -- Thursday
        weekday(date) >= 5           AS is_weekend,    -- Saturday or Sunday
        current_timestamp()          AS _loaded_at
    FROM days
"""

# Sales fact: one row per order line. The order's date, customer, place,
# status and payment are copied onto each line.
FACT_ORDER_ITEMS_SQL = """
    SELECT
        oi.order_item_id,
        oi.order_id,
        to_date(o.order_datetime) AS order_date,
        o.order_datetime,
        o.customer_id,
        oi.product_id,
        o.destination_city_id,
        os.order_status_name AS order_status,
        pt.payment_type_name AS payment_type,
        oi.quantity,
        oi.unit_price,
        oi.gross_sales,
        oi.discount_rate,
        oi.discount_amount,
        oi.net_sales,
        oi.profit_ratio,
        oi.profit,
        current_timestamp() AS _loaded_at
    FROM order_items oi
    JOIN orders o          ON o.order_id         = oi.order_id
    JOIN payment_types pt  ON pt.payment_type_id = o.payment_type_id
    JOIN order_statuses os ON os.order_status_id = o.order_status_id
"""

# Delivery fact: one row per shipment (one per order).
FACT_SHIPMENTS_SQL = """
    SELECT
        s.shipment_id,
        s.order_id,
        to_date(o.order_datetime)    AS order_date,
        to_date(s.shipping_datetime) AS shipping_date,
        s.shipping_datetime,
        o.customer_id,
        o.destination_city_id,
        sm.shipping_mode_name    AS shipping_mode,
        ds.delivery_status_name  AS delivery_status,
        os.order_status_name     AS order_status,
        sm.scheduled_shipping_days AS scheduled_days,
        s.actual_shipping_days     AS actual_days,
        s.actual_shipping_days - sm.scheduled_shipping_days AS delay_days,  -- > 0 = late
        ds.late_delivery_risk = 1 AS is_late,
        current_timestamp() AS _loaded_at
    FROM shipments s
    JOIN orders o             ON o.order_id            = s.order_id
    JOIN shipping_modes sm    ON sm.shipping_mode_id   = s.shipping_mode_id
    JOIN delivery_statuses ds ON ds.delivery_status_id = s.delivery_status_id
    JOIN order_statuses os    ON os.order_status_id    = o.order_status_id
"""

# Table name -> its query. Dimensions first, then facts.
WAREHOUSE_TABLES = {
    "dim_customer": DIM_CUSTOMER_SQL,
    "dim_product": DIM_PRODUCT_SQL,
    "dim_geography": DIM_GEOGRAPHY_SQL,
    "dim_date": DIM_DATE_SQL,
    "fact_order_items": FACT_ORDER_ITEMS_SQL,
    "fact_shipments": FACT_SHIPMENTS_SQL,
}


def main():
    args = parser.parse_args()
    spark = SparkSession.builder.appName("dataco-transform").getOrCreate()

    # Imported here (not at the top) so the tests can run without this library.
    from google.cloud import bigquery
    bq = bigquery.Client(project=args.project)

    # 1. Give each raw table a name, so the queries can say FROM orders, ...
    for table in RAW_TABLES:
        spark.read.parquet(f"gs://{args.bucket}/raw/{table}/").createOrReplaceTempView(table)

    # 2. Build each warehouse table and write it to BigQuery.
    for name, sql in WAREHOUSE_TABLES.items():
        df = spark.sql(sql)
        print(f"{name}: loading {df.count()} rows")

        bq.query(f"TRUNCATE TABLE dataco_dw.{name}").result()   # empty it first
        (
            df.write.format("bigquery")
            .option("writeMethod", "indirect")           # via files in the bucket
            .option("temporaryGcsBucket", args.bucket)
            .mode("append")                              # add rows, keep the table
            .save(f"{args.project}.dataco_dw.{name}")
        )

    spark.stop()


if __name__ == "__main__":
    main()
