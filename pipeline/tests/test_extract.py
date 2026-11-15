"""Tests for Job 1 (jobs/extract_mysql_to_gcs.py)."""
import pytest

from extract_mysql_to_gcs import TABLES, parser


def test_tables_match_schema_files(project_root):
    # The tables in the job must follow schema/01..17 exactly (same names, same order).
    files = sorted((project_root.parent / "schema").glob("[01][0-9]_*.sql"))
    names = [f.stem.split("_", 1)[1] for f in files if not f.stem.startswith("00")]
    assert list(TABLES) == names


def test_each_id_column_is_the_tables_auto_increment_key(project_root):
    # An incremental run copies "WHERE <id> > biggest id already copied",
    # which only works if MySQL gives every new row a bigger id.
    for table, id_column in TABLES.items():
        schema_file = next((project_root.parent / "schema").glob(f"[01][0-9]_{table}.sql"))
        text = schema_file.read_text()
        assert f"PRIMARY KEY ({id_column})" in text, table
        key_line = next(line for line in text.splitlines() if line.strip().startswith(id_column + " "))
        assert "AUTO_INCREMENT" in key_line, table


def test_arguments_for_a_full_load():
    args = parser.parse_args(["--project", "p", "--bucket", "b", "--mysql-host", "10.20.0.3"])
    assert (args.project, args.bucket, args.mysql_host, args.incremental) == ("p", "b", "10.20.0.3", False)


def test_incremental_flag():
    args = parser.parse_args(["--project", "p", "--bucket", "b", "--mysql-host", "h", "--incremental"])
    assert args.incremental is True


def test_mysql_host_is_required():
    with pytest.raises(SystemExit):
        parser.parse_args(["--project", "p", "--bucket", "b"])
