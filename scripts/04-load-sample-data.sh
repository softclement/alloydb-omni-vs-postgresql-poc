#!/usr/bin/env bash
# 04-load-sample-data.sh — identical schema + identical (setseed'd) data
# into AlloyDB Omni, PostgreSQL 17.9, and PostgreSQL 19 Beta 3.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-env.sh

load_into () {
  local container="$1" user="$2" db="$3" label="$4"
  echo "==> [$label] copying SQL files into container"
  $CONTAINER_RUNTIME cp "$SQL_DIR/schema.sql"    "$container:/tmp/schema.sql"
  $CONTAINER_RUNTIME cp "$SQL_DIR/seed_data.sql" "$container:/tmp/seed_data.sql"

  echo "==> [$label] creating schema"
  $CONTAINER_RUNTIME exec -i "$container" psql -U "$user" -d "$db" -f /tmp/schema.sql

  echo "==> [$label] loading sample data"
  local start end
  start=$(date +%s)
  $CONTAINER_RUNTIME exec -i "$container" psql -U "$user" -d "$db" -f /tmp/seed_data.sql
  end=$(date +%s)
  echo "==> [$label] load complete in $((end - start))s"
}

load_into "$ALLOYDB_CONTAINER" "$ALLOYDB_USER" "$ALLOYDB_DB" "AlloyDB Omni 17.9"
load_into "$PG17_CONTAINER"    "$PG17_USER"    "$PG17_DB"    "PostgreSQL 17.9"
load_into "$PG19_CONTAINER"    "$PG19_USER"    "$PG19_DB"    "PostgreSQL 19 Beta 3"

echo
echo "==> Row counts (must match across all three — setseed() makes this deterministic):"
row_count () {
  local container="$1" user="$2" db="$3"
  $CONTAINER_RUNTIME exec "$container" psql -U "$user" -d "$db" -tAc \
    "SELECT 'orders=' || (SELECT count(*) FROM orders) || ' order_items=' || (SELECT count(*) FROM order_items);"
}
alloy_counts=$(row_count "$ALLOYDB_CONTAINER" "$ALLOYDB_USER" "$ALLOYDB_DB")
pg17_counts=$(row_count "$PG17_CONTAINER" "$PG17_USER" "$PG17_DB")
pg19_counts=$(row_count "$PG19_CONTAINER" "$PG19_USER" "$PG19_DB")

printf "    %-24s %s\n" "AlloyDB Omni 17.9:"    "$alloy_counts"
printf "    %-24s %s\n" "PostgreSQL 17.9:"      "$pg17_counts"
printf "    %-24s %s\n" "PostgreSQL 19 Beta 3:" "$pg19_counts"

if [[ "$alloy_counts" == "$pg17_counts" && "$pg17_counts" == "$pg19_counts" ]]; then
  echo "    ✅ All three match — the dataset is genuinely identical across engines."
else
  echo "    ⚠️  Row counts DON'T match. That breaks the 'same data' comparison —"
  echo "        do not proceed to benchmarking until this is fixed. Most likely"
  echo "        cause: seed_data.sql was edited without keeping setseed() at the"
  echo "        top, or one container failed partway through the load above —"
  echo "        scroll up and check for errors."
fi
