-- =============================================================================
-- remove_test_orders.sql - delete the test rows again.
--
-- order_items and shipments are deleted automatically, because their
-- foreign keys to orders were created with ON DELETE CASCADE.
-- The orders go first: the customer and product can only be deleted once
-- no order (line) points at them any more.
-- Note: this only changes MySQL. The incremental job never deletes rows in
-- the lake, so run run_pipeline.sh (full load) afterwards to remove them
-- there and in BigQuery too.
-- =============================================================================
DELETE FROM orders WHERE order_id BETWEEN 77205 AND 77207;
DELETE FROM customers WHERE customer_id = 20758;
DELETE FROM products WHERE product_id = 1364;
