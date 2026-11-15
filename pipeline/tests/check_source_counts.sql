-- =============================================================================
-- check_source_counts.sql - did every MySQL table load completely?
--
-- expected_rows comes from the "-- Rows :" line at the top of each data file.
-- Run it through the Auth Proxy:  mysql --table dataco_supply_chain < tests/check_source_counts.sql
-- Every row should say OK.
-- =============================================================================
SELECT
    table_name,
    actual_rows,
    expected_rows,
    IF(actual_rows = expected_rows, 'OK', 'MISMATCH') AS status
FROM (
    SELECT 'markets' AS table_name, COUNT(*) AS actual_rows, 5 AS expected_rows FROM markets
    UNION ALL
    SELECT 'regions' AS table_name, COUNT(*) AS actual_rows, 23 AS expected_rows FROM regions
    UNION ALL
    SELECT 'countries' AS table_name, COUNT(*) AS actual_rows, 165 AS expected_rows FROM countries
    UNION ALL
    SELECT 'states' AS table_name, COUNT(*) AS actual_rows, 1119 AS expected_rows FROM states
    UNION ALL
    SELECT 'cities' AS table_name, COUNT(*) AS actual_rows, 4120 AS expected_rows FROM cities
    UNION ALL
    SELECT 'departments' AS table_name, COUNT(*) AS actual_rows, 11 AS expected_rows FROM departments
    UNION ALL
    SELECT 'categories' AS table_name, COUNT(*) AS actual_rows, 51 AS expected_rows FROM categories
    UNION ALL
    SELECT 'products' AS table_name, COUNT(*) AS actual_rows, 118 AS expected_rows FROM products
    UNION ALL
    SELECT 'customer_segments' AS table_name, COUNT(*) AS actual_rows, 3 AS expected_rows FROM customer_segments
    UNION ALL
    SELECT 'customers' AS table_name, COUNT(*) AS actual_rows, 20652 AS expected_rows FROM customers
    UNION ALL
    SELECT 'payment_types' AS table_name, COUNT(*) AS actual_rows, 4 AS expected_rows FROM payment_types
    UNION ALL
    SELECT 'order_statuses' AS table_name, COUNT(*) AS actual_rows, 9 AS expected_rows FROM order_statuses
    UNION ALL
    SELECT 'shipping_modes' AS table_name, COUNT(*) AS actual_rows, 4 AS expected_rows FROM shipping_modes
    UNION ALL
    SELECT 'delivery_statuses' AS table_name, COUNT(*) AS actual_rows, 4 AS expected_rows FROM delivery_statuses
    UNION ALL
    SELECT 'orders' AS table_name, COUNT(*) AS actual_rows, 65752 AS expected_rows FROM orders
    UNION ALL
    SELECT 'shipments' AS table_name, COUNT(*) AS actual_rows, 65752 AS expected_rows FROM shipments
    UNION ALL
    SELECT 'order_items' AS table_name, COUNT(*) AS actual_rows, 180519 AS expected_rows FROM order_items
) AS counts;
