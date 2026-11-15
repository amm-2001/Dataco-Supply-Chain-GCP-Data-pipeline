-- =============================================================================
-- DataCo Supply Chain - 3NF relational model for Cloud SQL for MySQL 8.0
-- Table      : categories
-- Load order : 07  (data file: data/07_categories.sql)
-- Depends on : departments
-- Grain      : one row per product category
-- Source cols: Category Id / Product Category Id, Category Name (-> Department Id)
-- =============================================================================

CREATE TABLE categories (
  category_id    SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Source Category Id (= Product Category Id)',
  category_name  VARCHAR(50)       NOT NULL               COMMENT 'Category name. Not globally unique (Electronics exists in 2 departments)',
  department_id  SMALLINT UNSIGNED NOT NULL               COMMENT 'FK -> departments',
  CONSTRAINT pk_categories PRIMARY KEY (category_id),
  CONSTRAINT uq_categories_dept_name UNIQUE (department_id, category_name),
  CONSTRAINT fk_categories_department FOREIGN KEY (department_id) REFERENCES departments (department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Product category; category -> department';
