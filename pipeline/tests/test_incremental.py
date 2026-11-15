"""Checks for the incremental load (chapter 12): each table copies the rows
whose id is bigger than the biggest id already in the lake."""
import re

import pytest


@pytest.mark.parametrize("table, data_file", [
    ("products", "08_products.sql"),
    ("customers", "10_customers.sql"),
    ("orders", "15_orders.sql"),
    ("shipments", "16_shipments.sql"),
    ("order_items", "17_order_items.sql"),
])
def test_test_rows_have_ids_after_every_real_row(project_root, table, data_file):
    # The new test product, customer, orders, lines and shipments must have
    # bigger ids than every real row, or an incremental run would not see them.
    def first_ids(text):
        return [int(n) for n in re.findall(r"^\((\d+),", text, re.MULTILINE)]

    newest_real_id = max(first_ids((project_root.parent / "data" / data_file).read_text()))
    test_sql = (project_root / "tests" / "new_test_orders.sql").read_text()
    block = test_sql.split(f"INSERT INTO {table} ")[1].split(";")[0]
    test_ids = first_ids(block)
    assert test_ids and min(test_ids) > newest_real_id


def test_test_orders_never_insert_generated_column(project_root):
    # gross_sales is computed by MySQL itself; inserting it is an error.
    lines = (project_root / "tests" / "new_test_orders.sql").read_text().splitlines()
    sql_lines = [line for line in lines if not line.startswith("--")]
    assert not any("gross_sales" in line for line in sql_lines)


def test_run_pipeline_passes_its_options_to_job_1_only(project_root):
    # "bash run_pipeline.sh --incremental" changes what Job 1 copies;
    # Job 2 always rebuilds the warehouse from the complete lake.
    lines = (project_root / "run_pipeline.sh").read_text().splitlines()
    job_argument_lines = [line for line in lines if line.strip().startswith("-- --project=")]
    assert len(job_argument_lines) == 2
    assert job_argument_lines[0].endswith(' "$@"')       # Job 1
    assert '"$@"' not in job_argument_lines[1]            # Job 2
