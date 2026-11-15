-- =============================================================================
-- 01_create_datasets.sql - the two BigQuery datasets (a dataset is a folder
-- of tables, like a "schema" in MySQL).
--
--   dataco_dw         the star schema: dimension and fact tables
--   dataco_reporting  views that Looker Studio reads
--
-- IF NOT EXISTS makes the file safe to run again.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS dataco_dw
OPTIONS (
  location = "US",
  description = "DataCo star schema: dimensions and facts"
);

CREATE SCHEMA IF NOT EXISTS dataco_reporting
OPTIONS (
  location = "US",
  description = "Flat views for Looker Studio"
);
