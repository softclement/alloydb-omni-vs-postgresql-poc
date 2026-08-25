-- columnar_demo.sql
-- Run this AFTER 04-run-feature-probes.sh so you have the confirmed
-- extension/GUC names for the AlloyDB image you actually pulled — Google
-- revises the google_columnar_engine.* names across Omni releases, so this
-- file is deliberately written as "try this, verify against the probe
-- output" rather than a guaranteed one-liner.
--
-- Section A runs on AlloyDB Omni only.
-- Section B (the plain aggregation query) runs unmodified on both engines —
-- that identical query is what you time and compare in the README table.

-- ===================== SECTION A — AlloyDB Omni only =====================
-- Don't run this section by hand — use scripts/05-enable-columnar-engine.sh,
-- which runs these same statements and handles the required container
-- restart for you. Left here for reference / for running manually inside
-- `podman exec -it alloydb-omni psql -U postgres -d pocdb`:
--
--   ALTER SYSTEM SET google_columnar_engine.enabled = 'on';   -- then RESTART the container
--   SELECT google_columnar_engine_add(relation => 'order_items');
--   SELECT google_columnar_engine_add(relation => 'products');
--   SELECT google_columnar_engine_add(relation => 'orders');
--
-- Source: Google Cloud AlloyDB Omni "Configure the columnar engine" and
-- "Manage column store content manually" docs. If you pulled a newer/older
-- Omni image than what these docs describe, re-check against
-- results/alloydb_probe.txt (step 2 and step 5) — function/GUC names have
-- moved across releases before.

-- ===================== SECTION B — identical on both engines =============
-- This is the query you actually time. No engine-specific syntax at all —
-- that's deliberate, so the comparison is fair. IMPORTANT: this PoC's
-- schema.sql puts b-tree indexes on order_id, product_id, and region_id —
-- exactly the columns this query joins/filters on. AlloyDB's own docs say
-- the optimizer may prefer an index scan over the column store when both
-- are viable, so don't be surprised if Section B alone doesn't show the
-- columnar engine being used at all. Section C below removes that variable.

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT
    r.region_name,
    date_trunc('month', o.order_date) AS order_month,
    COUNT(DISTINCT o.order_id)        AS orders,
    SUM(oi.line_total)                AS revenue,
    AVG(oi.line_total)                AS avg_line_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN regions r       ON r.region_id = o.region_id
GROUP BY r.region_name, date_trunc('month', o.order_date)
ORDER BY r.region_name, order_month;

-- A second, heavier analytical query (full scan + join + aggregate),
-- representative of the "reporting query that ruins your OLTP afternoon":
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT
    p.category,
    COUNT(*)            AS line_items,
    SUM(oi.quantity)     AS units_sold,
    SUM(oi.line_total)   AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;

-- ===================== SECTION C — AlloyDB Omni only, forced comparison ==
-- Temporarily tell the planner not to use indexes for this session only,
-- so the choice is genuinely row-store-seq-scan vs columnar-scan instead
-- of index-scan vs columnar-scan. This is a demo technique, NOT something
-- to do in production — it exists purely to show your team what the
-- columnar engine looks like when it actually gets picked.
--
-- SET LOCAL only works inside an explicit transaction block — psql -f runs
-- each statement autocommitted by default, so this needs BEGIN/COMMIT
-- wrapped around it or SET LOCAL silently does nothing (and warns).
--
-- Disabling index scans alone isn't always enough to force a columnar plan:
-- the planner is still free to fall back to a plain Seq Scan if its cost
-- estimate says that's cheaper than the columnar custom scan — and at this
-- PoC's data volume (~600k rows, a 5-category GROUP BY), Seq Scan genuinely
-- can be cheap enough to win on cost alone. That's not a misconfiguration;
-- it's the planner doing its job. Disabling enable_seqscan too leaves the
-- columnar scan as the only remaining path, which forces it into the plan
-- purely so your team can SEE it in action — not something to ever do
-- outside a demo.
BEGIN;
SET LOCAL enable_indexscan  = off;
SET LOCAL enable_bitmapscan = off;
SET LOCAL enable_seqscan    = off;

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT
    p.category,
    COUNT(*)            AS line_items,
    SUM(oi.quantity)     AS units_sold,
    SUM(oi.line_total)   AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;

COMMIT;
-- (all three enable_* GUCs automatically revert to session defaults once
-- the transaction ends — no explicit RESET needed.)
