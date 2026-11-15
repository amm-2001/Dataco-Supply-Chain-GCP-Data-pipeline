"""Checks for chapter 10: the BigQuery ML late-delivery model.

BigQuery ML only runs in the cloud, so these tests read the SQL files and
check the rules that keep the model honest:
  * no column that gives away the answer (data leakage) reaches the model,
  * one column, data_split, decides which rows train and which rows test,
  * the models learn only from 'train' rows and are scored on 'test' rows,
  * training, evaluating and predicting all use the same features view.
"""
import re

import sqlglot

ML_DIR = "bigquery/ml"

# The ten columns the model may learn from: all known when the order is placed.
FEATURES = [
    "shipping_mode", "market", "region", "customer_segment", "payment_type",
    "order_weekday", "order_month", "line_count", "total_quantity", "order_net_sales",
]
# Columns that are only known after delivery: they would give away the answer.
LEAKY = ["actual_days", "delay_days", "delivery_status", "shipping_date", "order_status", "is_late"]

TEST_START = "DATE '2017-07-01'"   # first day of the test months


def read(project_root, name):
    return (project_root / ML_DIR / name).read_text()


def without_comments(sql):
    return "\n".join(line.split("--")[0] for line in sql.splitlines())


def select_list(sql_after_as):
    """Column names between the first SELECT and its FROM."""
    body = re.search(r"SELECT(.*?)\bFROM\b", without_comments(sql_after_as), re.S).group(1)
    names = []
    for item in body.split(","):
        item = item.strip()
        if item:
            names.append(re.split(r"\s+AS\s+", item, flags=re.I)[-1].strip())
    return names


def test_ml_folder_has_four_files(project_root):
    names = sorted(path.name for path in (project_root / ML_DIR).glob("*.sql"))
    assert names == ["01_features_view.sql", "02_train_models.sql",
                     "03_evaluate_models.sql", "04_predict.sql"]


def test_features_view_outputs_only_safe_columns(project_root):
    sql = read(project_root, "01_features_view.sql")
    view = sqlglot.parse_one(sql, read="bigquery")
    outputs = [column.alias_or_name for column in view.expression.selects]
    assert outputs == ["shipment_id", "order_id", "order_date"] + FEATURES + ["late", "data_split"]


def test_features_view_splits_by_order_date(project_root):
    # Orders before 2017-07-01 train the models; newer orders test them.
    sql = without_comments(read(project_root, "01_features_view.sql"))
    assert f"IF(s.order_date < {TEST_START}, 'train', 'test') AS data_split" in sql


def test_features_view_leaves_out_cancelled_shipments(project_root):
    sql = without_comments(read(project_root, "01_features_view.sql"))
    assert "delivery_status != 'Shipping canceled'" in sql


def test_both_models_train_only_on_train_rows_with_the_same_safe_features(project_root):
    sql = without_comments(read(project_root, "02_train_models.sql"))
    models = re.findall(r"CREATE OR REPLACE MODEL (\S+)", sql)
    assert models == ["dataco_dw.late_delivery_logreg", "dataco_dw.late_delivery_boosted"]
    assert "MODEL_TYPE = 'LOGISTIC_REG'" in sql and "MODEL_TYPE = 'BOOSTED_TREE_CLASSIFIER'" in sql
    # NO_SPLIT: BigQuery must not hold back some training rows on its own.
    assert sql.count("DATA_SPLIT_METHOD = 'NO_SPLIT'") == 2
    assert sql.count("WHERE data_split = 'train'") == 2
    for part in sql.split("CREATE OR REPLACE MODEL")[1:]:
        columns = select_list(part.split(") AS", 1)[1])
        assert columns == FEATURES + ["late"]
        assert not set(columns) & set(LEAKY)


def test_evaluation_compares_both_models_and_the_simple_rule_on_test_rows(project_root):
    sql = without_comments(read(project_root, "03_evaluate_models.sql"))
    assert "ML.EVALUATE(MODEL dataco_dw.late_delivery_logreg" in sql
    assert "ML.EVALUATE(MODEL dataco_dw.late_delivery_boosted" in sql
    assert "shipping_mode IN ('First Class', 'Second Class')" in sql
    assert sql.count("WHERE data_split = 'test'") == 3
    for column in FEATURES:
        assert column in sql


def test_predictions_use_the_chosen_model_on_test_rows(project_root):
    sql = without_comments(read(project_root, "04_predict.sql"))
    assert "CREATE OR REPLACE TABLE dataco_reporting.late_delivery_risk" in sql
    assert "ML.PREDICT(MODEL dataco_dw.late_delivery_logreg" in sql
    assert "FROM dataco_dw.v_shipment_features" in sql
    assert "WHERE data_split = 'test'" in sql
    assert "WHERE p.label = 1" in sql  # the probability of "late", not of "on time"
    # Same names as in the reporting views, so chapter 11's market filter applies.
    assert "market AS market_name" in sql and "region AS region_name" in sql


def test_train_script_shows_the_split_and_runs_the_sql_files_in_order(project_root):
    script = (project_root / "ml" / "train_model.sh").read_text()
    positions = [script.index(f"bigquery/ml/{name}") for name in (
        "01_features_view.sql", "02_train_models.sql", "03_evaluate_models.sql", "04_predict.sql")]
    assert positions == sorted(positions)
    split_query = "GROUP BY data_split"
    assert positions[0] < script.index(split_query) < positions[1]


def test_predictions_are_refreshed_by_hand_only(project_root):
    # The data does not change for now, so nothing re-runs the model by itself.
    for path in ("run_pipeline.sh", "workflow/deploy_workflow.sh", "workflow/pipeline_workflow.yaml",
                 "setup/10_bigquery_tables.sh"):
        text = (project_root / path).read_text()
        for word in ("predict", "late_delivery", "ML_READY", "ml_ready"):
            assert word not in text, f"{path} still mentions {word}"
    setup = (project_root / "setup" / "10_bigquery_tables.sh").read_text()
    assert "ON SCHEMA dataco_reporting TO 'serviceAccount:$WORKFLOW_SA_EMAIL'" not in setup
