#!/usr/bin/env bash
# 05-run-feature-probes.sh — fingerprint all three engines, save results,
# and diff AlloyDB against each vanilla baseline separately.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-env.sh

probe () {
  local container="$1" user="$2" db="$3" outfile="$4" label="$5"
  echo "==> Probing $label"
  $CONTAINER_RUNTIME cp "$SQL_DIR/feature_probe.sql" "$container:/tmp/feature_probe.sql"
  $CONTAINER_RUNTIME exec "$container" psql -U "$user" -d "$db" \
    -f /tmp/feature_probe.sql > "$RESULTS_DIR/$outfile"
}

probe "$ALLOYDB_CONTAINER" "$ALLOYDB_USER" "$ALLOYDB_DB" "alloydb_probe.txt"       "AlloyDB Omni 17.9"
probe "$PG17_CONTAINER"    "$PG17_USER"    "$PG17_DB"    "vanilla17_probe.txt"    "PostgreSQL 17.9"
probe "$PG19_CONTAINER"    "$PG19_USER"    "$PG19_DB"    "vanilla19beta3_probe.txt" "PostgreSQL 19 Beta 3"

echo
echo "==> Saved:"
echo "    $RESULTS_DIR/alloydb_probe.txt"
echo "    $RESULTS_DIR/vanilla17_probe.txt"
echo "    $RESULTS_DIR/vanilla19beta3_probe.txt"

echo
echo "==> Diff: AlloyDB vs PostgreSQL 17.9 (the fair, same-version comparison)"
diff --side-by-side --width=160 "$RESULTS_DIR/vanilla17_probe.txt" "$RESULTS_DIR/alloydb_probe.txt" \
  > "$RESULTS_DIR/probe_diff_vs_pg17.txt" || true
echo "    $RESULTS_DIR/probe_diff_vs_pg17.txt"

echo
echo "==> Diff: AlloyDB vs PostgreSQL 19 Beta 3 (bonus track — includes version drift)"
diff --side-by-side --width=160 "$RESULTS_DIR/vanilla19beta3_probe.txt" "$RESULTS_DIR/alloydb_probe.txt" \
  > "$RESULTS_DIR/probe_diff_vs_pg19beta3.txt" || true
echo "    $RESULTS_DIR/probe_diff_vs_pg19beta3.txt"
