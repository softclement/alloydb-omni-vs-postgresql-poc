-- schema.sql
-- A small retail dataset: regions -> products -> orders -> order_items.
-- Runs identically on AlloyDB Omni and vanilla PostgreSQL 19 Beta 3 —
-- that's the point. Same DDL, same data, different engine underneath.

DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS regions CASCADE;

CREATE TABLE regions (
    region_id   SMALLINT PRIMARY KEY,
    region_name TEXT NOT NULL
);

CREATE TABLE products (
    product_id   SERIAL PRIMARY KEY,
    product_name TEXT NOT NULL,
    category     TEXT NOT NULL,
    unit_price   NUMERIC(10,2) NOT NULL
);

CREATE TABLE orders (
    order_id    BIGSERIAL PRIMARY KEY,
    region_id   SMALLINT NOT NULL REFERENCES regions(region_id),
    order_date  DATE NOT NULL,
    customer_id INTEGER NOT NULL
);

CREATE TABLE order_items (
    order_item_id BIGSERIAL PRIMARY KEY,
    order_id      BIGINT NOT NULL REFERENCES orders(order_id),
    product_id    INTEGER NOT NULL REFERENCES products(product_id),
    quantity      SMALLINT NOT NULL,
    line_total    NUMERIC(12,2) NOT NULL
);

-- Row-store friendly index — the kind you'd add on any OLTP system,
-- regardless of vendor.
CREATE INDEX idx_orders_region_date ON orders(region_id, order_date);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
