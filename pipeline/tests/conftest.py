"""Shared pytest setup.

pytest runs this file automatically before any test. It does two things:
1. lets the tests `import` the job files in pipeline/jobs/
2. gives every test a small local Spark session (no Google Cloud needed)
"""
import sys
from pathlib import Path

import pytest

PIPELINE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PIPELINE_DIR / "jobs"))


@pytest.fixture(scope="session")
def project_root():
    """The pipeline/ folder, so tests can find scripts and SQL files."""
    return PIPELINE_DIR


@pytest.fixture(scope="session")
def spark():
    """A tiny Spark that runs inside this machine with 2 threads.

    scope="session" means it starts once and is shared by all tests,
    because starting Spark takes a few seconds.
    """
    from pyspark.sql import SparkSession

    session = (
        SparkSession.builder.master("local[2]")
        .appName("dataco-tests")
        .config("spark.sql.session.timeZone", "UTC")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
    yield session
    session.stop()


def make_df(spark, rows, schema):
    """Build a small DataFrame for a test, like a raw table read from MySQL.

    rows   - list of tuples, one per row
    schema - column names and Spark types, e.g. "order_id BIGINT, name STRING"
    Every raw table also gets the _extracted_at column that Job 1 adds.
    """
    from pyspark.sql import functions as F

    return spark.createDataFrame(rows, schema).withColumn("_extracted_at", F.current_timestamp())
