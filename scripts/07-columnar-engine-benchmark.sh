#!/usr/bin/env bash
# 07-columnar-engine-benchmark.sh — same analytical queries, all THREE
# engines, one combined report: AlloyDB Omni 17.9, PostgreSQL 17.9 (fair
# baseline), PostgreSQL 19 Beta 3 (bonus track).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-env.sh

echo "⚠️  Have you run ./06-enable-columnar-engine.sh yet? Without it AlloyDB's"
echo "    columnar engine is off by default and Section C below won't show"
echo "    'Custom Scan (columnar scan)' no matter what."
echo

run_bench () {
  local container="$1" user="$2" db="$3" outfile="$4" label="$5"
  echo "==> Running analytical queries on $label"
  $CONTAINER_RUNTIME cp "$SQL_DIR/columnar_demo.sql" "$container:/tmp/columnar_demo.sql"
  $CONTAINER_RUNTIME exec "$container" psql -U "$user" -d "$db" \
    -f /tmp/columnar_demo.sql > "$RESULTS_DIR/$outfile"
}

run_bench "$ALLOYDB_CONTAINER" "$ALLOYDB_USER" "$ALLOYDB_DB" "alloydb_benchmark.txt"       "AlloyDB Omni 17.9"
run_bench "$PG17_CONTAINER"    "$PG17_USER"    "$PG17_DB"    "vanilla17_benchmark.txt"    "PostgreSQL 17.9"
run_bench "$PG19_CONTAINER"    "$PG19_USER"    "$PG19_DB"    "vanilla19beta3_benchmark.txt" "PostgreSQL 19 Beta 3"

echo
echo "==> Execution Time lines, side by side (Section B query 1 / query 2 / Section C):"
printf "%-24s %s\n" "AlloyDB Omni 17.9:"    "$(grep -i 'Execution Time' "$RESULTS_DIR/alloydb_benchmark.txt" | tr '\n' ' ')"
printf "%-24s %s\n" "PostgreSQL 17.9:"      "$(grep -i 'Execution Time' "$RESULTS_DIR/vanilla17_benchmark.txt" | tr '\n' ' ')"
printf "%-24s %s\n" "PostgreSQL 19 Beta 3:" "$(grep -i 'Execution Time' "$RESULTS_DIR/vanilla19beta3_benchmark.txt" | tr '\n' ' ')"
echo
echo "    Read PostgreSQL 19 Beta 3's numbers as a SEPARATE 'core Postgres"
echo "    progress' track — it's two major versions ahead of AlloyDB's base,"
echo "    so don't present it as 'AlloyDB vs vanilla' on the same slide as"
echo "    the PostgreSQL 17.9 numbers."

echo
echo "==> Did the columnar engine actually get used?"
columnar_hits=$(grep -c -i "Custom Scan (columnar scan)" "$RESULTS_DIR/alloydb_benchmark.txt" || true)
if [[ "${columnar_hits:-0}" -gt 0 ]]; then
  echo "    YES — 'Custom Scan (columnar scan)' appears ${columnar_hits} time(s) in the AlloyDB plan."
else
  echo "    NO — no 'Custom Scan (columnar scan)' node found anywhere in the AlloyDB plan."
  echo "    Confirm 06-enable-columnar-engine.sh finished with all columns"
  echo "    showing status = Usable, and that you haven't reloaded AlloyDB's"
  echo "    data since (which resets the column store — see that script's header)."
fi

echo
echo "Full plans saved to:"
echo "    $RESULTS_DIR/alloydb_benchmark.txt"
echo "    $RESULTS_DIR/vanilla17_benchmark.txt"
echo "    $RESULTS_DIR/vanilla19beta3_benchmark.txt"
