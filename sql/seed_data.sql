-- seed_data.sql
-- Reference data is small and hand-written; the fact tables (orders,
-- order_items) are bulk-generated with generate_series.
--
-- setseed() makes random() deterministic WITHIN this script, so loading
-- this same file into AlloyDB, PostgreSQL 17.9, and PostgreSQL 19 Beta 3
-- produces IDENTICAL row counts and IDENTICAL values on all three —
-- that's what makes the 3-way comparison a fair one. Without this, every
-- container ends up with a different random dataset, which is exactly
-- what happened before this was added (row counts differed by container).
SELECT setseed(0.42);

INSERT INTO regions (region_id, region_name) VALUES
    (1, 'North America'),
    (2, 'EMEA'),
    (3, 'APAC'),
    (4, 'LATAM'),
    (5, 'India');

INSERT INTO products (product_name, category, unit_price)
SELECT
    'Product ' || g,
    (ARRAY['Electronics','Home','Grocery','Apparel','Books'])[1 + (g % 5)],
    round((random() * 490 + 10)::numeric, 2)
FROM generate_series(1, 40) AS g;

-- 200,000 orders spread across the last 24 months
INSERT INTO orders (region_id, order_date, customer_id)
SELECT
    1 + (random() * 4)::int,
    date '2024-08-01' + (random() * 730)::int,
    1 + (random() * 50000)::int
FROM generate_series(1, 200000);

-- 1-3 line items per order (~400,000 rows total). Each order gets a small
-- generate_series fan-out instead of a single-row LATERAL, which is what
-- an earlier version of this script got wrong — that version only ever
-- produced one row per order no matter what the fan-out comment claimed.
INSERT INTO order_items (order_id, product_id, quantity, line_total)
SELECT
    o.order_id,
    pid.product_id,
    qty.quantity,
    round((p.unit_price * qty.quantity)::numeric, 2)
FROM orders o
CROSS JOIN LATERAL generate_series(1, 1 + floor(random() * 3)::int) AS item(item_num)
CROSS JOIN LATERAL (SELECT (1 + floor(random() * 40))::int AS product_id) pid
CROSS JOIN LATERAL (SELECT (1 + floor(random() * 4))::int AS quantity) qty
JOIN products p ON p.product_id = pid.product_id;

ANALYZE regions;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;
