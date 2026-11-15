"""Checks for the BigQuery SQL files (syntax + the column contract)."""
import sqlglot
from sqlglot import exp

from contract import CONTRACT


def sql_files(project_root):
    """All BigQuery SQL files that the pipeline runs."""
    files = sorted((project_root / "bigquery").glob("*.sql"))
    files += sorted((project_root / "tests").glob("data_quality*.sql"))
    return files


def parse_create_tables(sql):
    """Return {table_name: [(column, TYPE), ...]} for every CREATE TABLE."""
    tables = {}
    for statement in sqlglot.parse(sql, read="bigquery"):
        if isinstance(statement, exp.Create) and statement.kind == "TABLE":
            schema = statement.this  # the table name + its column list
            name = schema.this.name
            columns = []
            for column in schema.expressions:
                if isinstance(column, exp.ColumnDef):
                    type_sql = column.args["kind"].sql(dialect="bigquery").upper()
                    columns.append((column.name, type_sql))
            tables[name] = columns
    return tables


def test_all_sql_files_parse_as_bigquery(project_root):
    files = sql_files(project_root)
    assert files, "no SQL files found"
    for path in files:
        sqlglot.parse(path.read_text(), read="bigquery")  # raises on a syntax error


def test_ddl_matches_contract(project_root):
    ddl = parse_create_tables((project_root / "bigquery" / "02_create_tables.sql").read_text())
    assert ddl == CONTRACT


def test_fact_tables_are_partitioned_and_clustered(project_root):
    text = (project_root / "bigquery" / "02_create_tables.sql").read_text()
    assert "PARTITION BY DATE_TRUNC(order_date, MONTH)" in text
    assert "PARTITION BY DATE_TRUNC(shipping_date, MONTH)" in text
    assert "CLUSTER BY product_id, customer_id" in text
    assert "CLUSTER BY shipping_mode, delivery_status" in text


def without_comments(sql):
    """Drop "--" comment lines, so words in comments are not counted."""
    return "\n".join(line for line in sql.splitlines() if not line.strip().startswith("--"))


def test_every_table_has_a_primary_key(project_root):
    text = without_comments((project_root / "bigquery" / "02_create_tables.sql").read_text())
    assert text.count("PRIMARY KEY") == len(CONTRACT)              # one per table
    assert text.count("NOT ENFORCED") == len(CONTRACT) + 8         # 6 PKs + 8 FKs
