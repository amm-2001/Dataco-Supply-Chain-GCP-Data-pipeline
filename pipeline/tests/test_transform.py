"""
Tests for Job 2's SQL queries, using a tiny hand-made copy of the
source data. Orders 1 and 7 and their lines are REAL rows from the data files:

  order 1: 1 line  (product 957),            Standard Class, 2 days, early
  order 7: 3 lines (products 1073, 957, 926), Second Class,   3 days, late

Run:  python -m pytest tests/test_transform.py -v
"""
from datetime import date, datetime
from decimal import Decimal

import pytest

from conftest import make_df
from contract import CONTRACT
from extract_mysql_to_gcs import TABLES as JOB1_TABLES
from transform_to_warehouse import RAW_TABLES, WAREHOUSE_TABLES, parser

# Spark type name -> BigQuery type in the contract.
# BigQuery has one whole-number type, INT64, for all of Spark's integer types.
SPARK_TO_BIGQUERY = {
    "tinyint": "INT64",
    "smallint": "INT64",
    "int": "INT64",
    "bigint": "INT64",
    "string": "STRING",
    "double": "FLOAT64",
    "date": "DATE",
    "timestamp_ntz": "DATETIME",
    "timestamp": "TIMESTAMP",
    "boolean": "BOOL",
}


def bigquery_type(spark_type):
    """Translate a Spark dtype string (e.g. "decimal(10,2)") to a BigQuery type."""
    if spark_type.startswith("decimal"):
        return "NUMERIC"
    return SPARK_TO_BIGQUERY[spark_type]


def d(text):
    """Shortcut for an exact decimal number, like MySQL DECIMAL."""
    return Decimal(text)


@pytest.fixture(scope="module")
def raw(spark):
    """The raw tables, with the column names and types Job 1 produces."""
    return {
        "markets": make_df(spark, [(3, "LATAM"), (5, "USCA")],
                           "market_id INT, market_name STRING"),
        "regions": make_df(spark, [(4, "Central America", 3), (15, "South of USA", 5)],
                           "region_id INT, region_name STRING, market_id INT"),
        "countries": make_df(spark, [(100, "Mexico", "MX"), (157, "United States", "US")],
                             "country_id INT, country_name STRING, iso_alpha2 STRING"),
        "states": make_df(spark, [
            (1, 157, "Texas", "TX", 15),
            (2, 100, "Jalisco", None, 4),
            (3, 157, "Vermont", "VT", None),   # a state with no region
        ], "state_id INT, country_id INT, state_name STRING, state_code STRING, region_id INT"),
        "cities": make_df(spark, [
            (2151, 1, "Houston"), (446, 2, "Guadalajara"), (99, 3, "Burlington"), (2516, 1, "Dallas"),
        ], "city_id BIGINT, state_id INT, city_name STRING"),
        "departments": make_df(spark, [(4, "Apparel"), (7, "Fan Shop")],
                               "department_id INT, department_name STRING"),
        "categories": make_df(spark, [(17, "Cleats", 4), (46, "Indoor/Outdoor Games", 7)],
                              "category_id INT, category_name STRING, department_id INT"),
        "products": make_df(spark, [
            (957, "Diamondback Women's Serene Classic", 46, d("299.98"), None, None, 0),
            (1073, "Pelican Sunstream 100 Kayak", 46, d("199.99"), None, None, 1),
            (926, "Glove It Imperial Golf Towel", 17, d("15.99"), None, None, 0),
        ], "product_id BIGINT, product_name STRING, category_id INT, product_price DECIMAL(10,2), "
           "product_image_url STRING, product_description STRING, product_status INT"),
        "customer_segments": make_df(spark, [(1, "Consumer"), (2, "Corporate")],
                                     "segment_id INT, segment_name STRING"),
        "customers": make_df(spark, [
            (11599, "Mary", "Malone", None, 1, "8510 Round Bear Gate", 2516, "75201",
             d("32.77695465"), d("-96.79664612")),
            (4530, "Richard", "Hernandez", None, 2, "6303 Heather Plaza", 2151, "77002",
             d("29.76044083"), d("-95.36980438")),
            (2, "Mary", None, None, 1, "1 Main St", 2151, "77002", None, None),  # no last name
        ], "customer_id BIGINT, first_name STRING, last_name STRING, email STRING, segment_id INT, "
           "street STRING, city_id BIGINT, zipcode STRING, latitude DECIMAL(10,8), longitude DECIMAL(11,8)"),
        "payment_types": make_df(spark, [(1, "CASH"), (2, "DEBIT")],
                                 "payment_type_id INT, payment_type_name STRING"),
        "order_statuses": make_df(spark, [(2, "CLOSED"), (3, "COMPLETE")],
                                  "order_status_id INT, order_status_name STRING"),
        "shipping_modes": make_df(spark, [(3, "Second Class", 2), (4, "Standard Class", 4)],
                                  "shipping_mode_id INT, shipping_mode_name STRING, scheduled_shipping_days INT"),
        "delivery_statuses": make_df(spark, [(1, "Advance shipping", 0), (2, "Late delivery", 1)],
                                     "delivery_status_id INT, delivery_status_name STRING, late_delivery_risk INT"),
        "orders": make_df(spark, [
            (1, 11599, datetime(2015, 1, 1, 0, 0), 1, 2, 2151, None),
            (7, 4530, datetime(2015, 1, 1, 2, 6), 2, 3, 446, None),
        ], "order_id BIGINT, customer_id BIGINT, order_datetime TIMESTAMP_NTZ, payment_type_id INT, "
           "order_status_id INT, destination_city_id BIGINT, destination_zipcode STRING"),
        "shipments": make_df(spark, [
            (1, 1, 4, datetime(2015, 1, 3, 0, 0), 2, 1),
            (5, 7, 3, datetime(2015, 1, 4, 2, 6), 3, 2),
        ], "shipment_id BIGINT, order_id BIGINT, shipping_mode_id INT, shipping_datetime TIMESTAMP_NTZ, "
           "actual_shipping_days INT, delivery_status_id INT"),
        "order_items": make_df(spark, [
            (1, 1, 957, 1, d("299.98"), d("299.98"), d("0.2000"), d("60.00"), d("239.98"), d("0.3700"), d("88.79")),
            (14, 7, 1073, 1, d("199.99"), d("199.99"), d("0.0200"), d("4.00"), d("195.99"), d("0.4000"), d("78.40")),
            (15, 7, 957, 1, d("299.98"), d("299.98"), d("0.1600"), d("48.00"), d("251.98"), d("0.4800"), d("120.95")),
            (16, 7, 926, 5, d("15.99"), d("79.95"), d("0.0300"), d("2.40"), d("77.55"), d("0.0600"), d("4.58")),
        ], "order_item_id BIGINT, order_id BIGINT, product_id BIGINT, quantity INT, unit_price DECIMAL(10,2), "
           "gross_sales DECIMAL(12,2), discount_rate DECIMAL(5,4), discount_amount DECIMAL(10,2), "
           "net_sales DECIMAL(12,2), profit_ratio DECIMAL(6,4), profit DECIMAL(12,2)"),
    }


def register_views(raw):
    """Make each raw DataFrame queryable by name in Spark SQL, as Job 2 does."""
    for name, df in raw.items():
        df.createOrReplaceTempView(name)


def run_queries(spark):
    """Run every warehouse query, as Job 2 does: {table name: DataFrame}."""
    return {name: spark.sql(sql) for name, sql in WAREHOUSE_TABLES.items()}


@pytest.fixture(scope="module")
def built_tables(spark, raw):
    """Run every query once; all tests below look at the results."""
    register_views(raw)
    return run_queries(spark)


def test_each_query_matches_contract_columns(built_tables):
    for name, df in built_tables.items():
        assert df.columns == [column for column, _ in CONTRACT[name]], name


def test_each_query_matches_contract_types(built_tables):
    for name, df in built_tables.items():
        actual = [(column, bigquery_type(spark_type)) for column, spark_type in df.dtypes]
        assert actual == CONTRACT[name], name


def test_order_with_three_lines_gives_three_fact_rows_one_shipment(built_tables):
    items = built_tables["fact_order_items"].filter("order_id = 7")
    ships = built_tables["fact_shipments"].filter("order_id = 7")
    assert items.count() == 3 and ships.count() == 1


def test_fact_order_items_values(built_tables):
    row = built_tables["fact_order_items"].filter("order_item_id = 16").first()
    assert (row.order_date, row.order_datetime) == (date(2015, 1, 1), datetime(2015, 1, 1, 2, 6))
    assert (row.customer_id, row.product_id, row.destination_city_id) == (4530, 926, 446)
    assert (row.order_status, row.payment_type) == ("COMPLETE", "DEBIT")
    assert (row.quantity, row.gross_sales, row.net_sales, row.profit) == (5, d("79.95"), d("77.55"), d("4.58"))


def test_delay_and_is_late(built_tables):
    row = built_tables["fact_shipments"].filter("order_id = 7").first()
    assert (row.scheduled_days, row.actual_days, row.delay_days, row.is_late) == (2, 3, 1, True)
    assert (row.shipping_mode, row.delivery_status, row.order_status) == ("Second Class", "Late delivery", "COMPLETE")
    row1 = built_tables["fact_shipments"].filter("order_id = 1").first()
    assert (row1.delay_days, row1.is_late) == (-2, False)
    assert (row1.order_date, row1.shipping_date) == (date(2015, 1, 1), date(2015, 1, 3))


def test_unknown_region_and_market(built_tables):
    row = built_tables["dim_geography"].filter("city_id = 99").first()  # Vermont has no region
    assert (row.region_name, row.market_name) == ("Unknown", "Unknown")
    houston = built_tables["dim_geography"].filter("city_id = 2151").first()
    assert (houston.state_code, houston.country_iso2, houston.region_name, houston.market_name) == (
        "TX", "US", "South of USA", "USCA")


def test_full_name_without_last_name(built_tables):
    row = built_tables["dim_customer"].filter("customer_id = 2").first()
    assert row.full_name == "Mary"
    malone = built_tables["dim_customer"].filter("customer_id = 11599").first()
    assert (malone.full_name, malone.segment_name, malone.city_name, malone.state_name) == (
        "Mary Malone", "Consumer", "Dallas", "Texas")
    assert malone.latitude == pytest.approx(32.77695465)


def test_product_status_label(built_tables):
    labels = {r.product_id: r.product_status for r in built_tables["dim_product"].collect()}
    assert labels == {957: "Available", 1073: "Not available", 926: "Available"}
    golf = built_tables["dim_product"].filter("product_id = 926").first()
    assert (golf.category_name, golf.department_name) == ("Cleats", "Apparel")


def test_dim_date_is_a_full_calendar_with_iso_weekdays(built_tables):
    dates = built_tables["dim_date"].orderBy("date").collect()
    assert dates[0].date == date(2015, 1, 1) and dates[-1].date == date(2030, 12, 31)
    assert len(dates) == (date(2030, 12, 31) - date(2015, 1, 1)).days + 1   # no missing days
    assert [(r.day_name, r.day_of_week, r.is_weekend) for r in dates[:4]] == [
        ("Thursday", 4, False), ("Friday", 5, False), ("Saturday", 6, True), ("Sunday", 7, True)]
    assert (dates[0].year_month, dates[0].month_name, dates[0].quarter) == ("2015-01", "January", 1)


# ---------------------------------------------------------------------------
# The table lists and the command-line arguments
# ---------------------------------------------------------------------------


def test_job2_reads_the_same_tables_job1_writes():
    assert RAW_TABLES == list(JOB1_TABLES)


def test_warehouse_tables_in_contract_order_dimensions_first():
    assert list(WAREHOUSE_TABLES) == list(CONTRACT)


def test_job2_arguments():
    args = parser.parse_args(["--project", "p", "--bucket", "b"])
    assert (args.project, args.bucket) == ("p", "b")


def test_types_survive_the_parquet_round_trip(spark, raw, tmp_path):
    # Job 1 saves raw tables as Parquet; Job 2 reads them back. The DATETIME
    # columns (timestamp_ntz) and money columns (decimal) must survive that trip.
    reread = {}
    for table, df in raw.items():
        df.write.parquet(str(tmp_path / table))
        reread[table] = spark.read.parquet(str(tmp_path / table))
    register_views(reread)
    try:
        for name, df in run_queries(spark).items():
            actual = [(column, bigquery_type(spark_type)) for column, spark_type in df.dtypes]
            assert actual == CONTRACT[name], name
    finally:
        register_views(raw)  # put the original views back for any later test
