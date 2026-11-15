"""Checks for the bash scripts and text files (no Google Cloud needed)."""
import shutil
import subprocess
import sys
from pathlib import Path


def shellcheck_command():
    """Find shellcheck: on the PATH, or next to this Python (pip installs it there)."""
    return shutil.which("shellcheck") or str(Path(sys.executable).parent / "shellcheck")


def shell_scripts(project_root):
    """Every .sh file in the project, sorted so failures are easy to read."""
    return sorted(project_root.rglob("*.sh"))


def test_no_crlf_in_project_files(project_root):
    # Files saved on Windows end lines with \r\n, which breaks bash.
    for path in project_root.rglob("*"):
        if path.suffix in {".sh", ".py", ".sql", ".yaml", ".txt"}:
            assert b"\r\n" not in path.read_bytes(), f"{path} has Windows line endings"


def test_shell_scripts_pass_shellcheck(project_root):
    scripts = [str(p) for p in shell_scripts(project_root)]
    assert scripts, "no shell scripts found"
    result = subprocess.run(
        [shellcheck_command(), "-x", "-P", "SCRIPTDIR", *scripts],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout


def test_shell_scripts_start_with_set_e(project_root):
    # config.sh is excluded: it is "sourced" into your own terminal, and
    # `set -e` there would close your terminal on the first typo.
    for path in shell_scripts(project_root):
        if path.name == "config.sh":
            continue
        lines = path.read_text().splitlines()
        assert lines[0] == "#!/bin/bash", path
        assert any(line.startswith("set -e") for line in lines[:20]), path


def test_setup_scripts_guard_creates(project_root):
    # A beginner will re-run a script after an error. Every "create" must be
    # protected by a "describe"/"list" check so the re-run does not fail with
    # "already exists".
    for path in sorted((project_root / "setup").glob("[0-9]*.sh")):
        text = path.read_text()
        creates = text.count(" create ")
        guards = text.count(" describe ") + text.count(" list ")
        assert guards >= creates, f"{path.name}: every create needs a describe/list guard"


def test_mysql_scripts_check_connection_first(project_root):
    # If the Auth Proxy is not running, stop at once with a helpful message
    # instead of failing halfway through loading the data.
    for name in ["07_load_source_data.sh", "08_create_etl_user.sh"]:
        text = (project_root / "setup" / name).read_text()
        first_mysql = text.index("mysql ")
        assert text[first_mysql:].startswith('mysql -e "SELECT 1"'), name
        assert "cloud-sql-proxy" in text, name


def test_source_count_expectations_match_data_files(project_root):
    # Every "-- Rows : N" header in data/*.sql must appear in the check query.
    import re

    check_sql = (project_root / "tests" / "check_source_counts.sql").read_text()
    for path in sorted((project_root.parent / "data").glob("*.sql")):
        table = path.stem.split("_", 1)[1]
        rows = re.search(r"-- Rows\s*:\s*(\d+)", path.read_text()).group(1)
        assert f"'{table}' AS table_name, COUNT(*) AS actual_rows, {rows} AS expected_rows FROM {table}" in check_sql, table


def test_quality_checks_cover_every_table(project_root):
    from contract import CONTRACT

    text = (project_root / "tests" / "data_quality_checks.sql").read_text()
    assert_lines = [line for line in text.splitlines() if line.startswith("ASSERT")]
    for table in CONTRACT:
        assert any(table in line for line in assert_lines), table


def code_lines(text):
    """The lines of a bash script that are not comments."""
    return [line for line in text.splitlines() if not line.strip().startswith("#")]


def test_workflow_yaml_is_valid_and_has_steps(project_root):
    import yaml

    doc = yaml.safe_load((project_root / "workflow" / "pipeline_workflow.yaml").read_text())
    steps = [list(step)[0] for step in doc["main"]["steps"]]
    assert steps == ["init", "check_cloud_sql", "extract", "check_extract", "transform",
                     "check_transform", "run_checks", "done"]


def test_workflow_and_scripts_use_the_same_job_arguments(project_root):
    # The scheduled workflow must call the jobs exactly like run_pipeline.sh.
    workflow = (project_root / "workflow" / "pipeline_workflow.yaml").read_text()
    for flag in ["--project=", "--bucket=", "--mysql-host="]:
        assert flag in workflow, flag
        assert flag in (project_root / "run_pipeline.sh").read_text(), flag


def test_cleanup_requires_typed_confirmation(project_root):
    text = "\n".join(code_lines((project_root / "cleanup.sh").read_text()))
    assert "read -r -p" in text and '"DELETE"' in text
    assert text.index('"DELETE"') < text.index(" delete ")


def test_cleanup_tolerates_slow_network_releases(project_root):
    # Right after Cloud SQL is deleted, Google often refuses to remove the
    # peering for a while. That must print advice, not abort the script.
    text = (project_root / "cleanup.sh").read_text()
    assert "if ! gcloud services vpc-peerings delete" in text
    assert "if ! gcloud compute addresses delete" in text


def test_mysql_scripts_show_the_real_error(project_root):
    # "Start the proxy" is only ONE possible cause; show MySQL's own message
    # too (wrong password, login method, stopped instance...).
    for name in ["07_load_source_data.sh", "08_create_etl_user.sh"]:
        text = (project_root / "setup" / name).read_text()
        assert 'MYSQL_ERROR=$(mysql -e "SELECT 1" 2>&1)' in text, name
        assert 'echo "$MYSQL_ERROR"' in text, name


def test_cloud_sql_script_waits_until_runnable(project_root):
    # Creating the instance can take longer than gcloud waits; on a re-run the
    # instance "exists" but is not ready yet. Wait before creating the database.
    text = (project_root / "setup" / "06_cloud_sql.sh").read_text()
    assert 'until [ "$STATE" = "RUNNABLE" ]' in text
    assert text.index('until [ "$STATE" = "RUNNABLE" ]') < text.index("gcloud sql databases create")


def test_budget_script_checks_the_billing_currency(project_root):
    # A budget must be in the billing account's own currency; a non-USD
    # account would make "--budget-amount=50USD" fail.
    text = (project_root / "setup" / "02_budget_alert.sh").read_text()
    assert "currencyCode" in text
    assert text.index("currencyCode") < text.index("gcloud billing budgets create")


def test_workflow_stops_when_a_spark_batch_did_not_succeed(project_root):
    # Never run the checks (on yesterday's data) after a failed Spark job.
    text = (project_root / "workflow" / "pipeline_workflow.yaml").read_text()
    assert 'extract_batch.state != "SUCCEEDED"' in text
    assert 'transform_batch.state != "SUCCEEDED"' in text


def test_enable_apis_includes_cloud_resource_manager(project_root):
    # Runtime 3.0 reads secure tags for its firewall policy through this API;
    # without it, a batch fails with "Cloud Resource Manager API has not been used".
    script = (project_root / "setup" / "01_enable_apis.sh").read_text()
    assert "cloudresourcemanager.googleapis.com" in script


def test_workflow_starts_spark_batches_through_the_rest_api(project_root):
    # Workflows has no connector for Dataproc batches ("symbol ... not found"),
    # so the workflow calls the REST API itself and checks until the batch ends.
    import re
    import yaml

    text = (project_root / "workflow" / "pipeline_workflow.yaml").read_text()
    connectors = {name.split(".")[1] for name in re.findall(r"call: googleapis\.(\S+)", text)
                  for name in ["x." + name]}
    assert connectors <= {"bigquery", "sqladmin"}, connectors
    doc = yaml.safe_load(text)
    run_batch = doc["run_batch"]
    assert run_batch["params"] == ["parent", "batch_id", "body"]
    steps = [list(step)[0] for step in run_batch["steps"]]
    assert steps == ["submit", "wait", "check", "still_running", "finished"]
    assert text.count("call: run_batch") == 2
    assert "https://dataproc.googleapis.com/v1/" in text
    assert text.count("type: OAuth2") == 2
