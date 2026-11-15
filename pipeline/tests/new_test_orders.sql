-- =============================================================================
-- new_test_orders.sql - add NEW rows to MySQL, to test the incremental load.
--
-- A new product (1364) and a new customer (20758), then 3 new orders
-- (77205-77207) in which that customer buys that product.
-- Every id is bigger than the biggest real id of its table, so the
-- incremental job must pick up exactly these rows:
--   1 product, 1 customer, 3 orders, 6 order lines, 3 shipments.
-- gross_sales is NOT listed: MySQL calculates it (generated column).
--
-- Run through the Auth Proxy:   mysql dataco_supply_chain < tests/new_test_orders.sql
-- Undo with:                    mysql dataco_supply_chain < tests/remove_test_orders.sql
-- =============================================================================
SET NAMES utf8mb4;
START TRANSACTION;

INSERT INTO products (product_id, product_name, category_id, product_price, product_image_url, product_description, product_status) VALUES
(1364, 'Test Trail Running Shoe', 2, 149.99, NULL, NULL, 0);

INSERT INTO customers (customer_id, first_name, last_name, email, segment_id, street, city_id, zipcode, latitude, longitude) VALUES
(20758, 'Test', 'Customer', NULL, 1, '1 Test Street', 3919, '78521', 25.95364761, -97.50768280);

INSERT INTO orders (order_id, customer_id, order_datetime, payment_type_id, order_status_id, destination_city_id, destination_zipcode) VALUES
(77205, 20758, '2018-02-01 08:00:00', 1, 3, 2151, NULL),
(77206, 20758, '2018-02-01 09:00:00', 1, 3, 2151, NULL),
(77207, 20758, '2018-02-01 10:00:00', 1, 3, 2151, NULL);

INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, discount_rate, discount_amount, net_sales, profit_ratio, profit) VALUES
(180520, 77205, 1364, 1, 149.99, 0.1000, 15.00, 134.99, 0.3000, 40.50),
(180521, 77205, 1073, 1, 199.99, 0.0500, 10.00, 189.99, 0.2000, 38.00),
(180522, 77206, 1364, 1, 149.99, 0.1000, 15.00, 134.99, 0.3000, 40.50),
(180523, 77206, 1073, 1, 199.99, 0.0500, 10.00, 189.99, 0.2000, 38.00),
(180524, 77207, 1364, 1, 149.99, 0.1000, 15.00, 134.99, 0.3000, 40.50),
(180525, 77207, 1073, 1, 199.99, 0.0500, 10.00, 189.99, 0.2000, 38.00);

INSERT INTO shipments (shipment_id, order_id, shipping_mode_id, shipping_datetime, actual_shipping_days, delivery_status_id) VALUES
(65753, 77205, 4, '2018-02-04 08:00:00', 3, 1),
(65754, 77206, 4, '2018-02-04 09:00:00', 3, 1),
(65755, 77207, 4, '2018-02-04 10:00:00', 3, 1);

COMMIT;
