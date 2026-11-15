-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : departments
-- Load order : 06  (data file: data/06_departments.sql)
-- Depends on : -
-- Grain      : one row per store department
-- Source cols: Department Id, Department Name
-- =============================================================================

CREATE TABLE departments (
  department_id    SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Source Department Id',
  department_name  VARCHAR(40)       NOT NULL               COMMENT 'Department name of the store',
  CONSTRAINT pk_departments PRIMARY KEY (department_id),
  CONSTRAINT uq_departments_name UNIQUE (department_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Store department (top of the product hierarchy)';
