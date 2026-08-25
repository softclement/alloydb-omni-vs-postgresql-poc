#!/usr/bin/env bash
# 06-enable-columnar-engine.sh — turns on AlloyDB Omni's columnar engine
# and columnarizes the fact tables the demo query touches.
#
# IMPORTANT: this script only ever touches $ALLOYDB_CONTAINER. It never
# reloads data — reloading data means DROP/CREATE TABLE, which changes
# table OIDs and silently drops the columnar registration this script
# just set up. If you ever need to reload AlloyDB's data, re-run this
# script again afterward.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-env.sh

echo "==> Enabling the columnar engine flag (requires a restart to take effect)"
$CONTAINER_RUNTIME exec "$ALLOYDB_CONTAINER" psql -U "$ALLOYDB_USER" -d "$ALLOYDB_DB" -c \
  "ALTER SYSTEM SET google_columnar_engine.enabled = 'on';"

echo "==> Restarting ${ALLOYDB_CONTAINER} so the flag takes effect"
$CONTAINER_RUNTIME restart "$ALLOYDB_CONTAINER"

echo "==> Waiting for AlloyDB Omni to come back up..."
wait_for_pg_ready "$ALLOYDB_CONTAINER" "$ALLOYDB_USER"

echo "==> Confirming the flag is on"
$CONTAINER_RUNTIME exec "$ALLOYDB_CONTAINER" psql -U "$ALLOYDB_USER" -d "$ALLOYDB_DB" -c \
  "SHOW google_columnar_engine.enabled;"

echo "==> Adding order_items, products, and orders to the column store"
add_result=$($CONTAINER_RUNTIME exec "$ALLOYDB_CONTAINER" psql -U "$ALLOYDB_USER" -d "$ALLOYDB_DB" -tAc \
  "SELECT google_columnar_engine_add(relation => 'order_items');" 2>&1) || true
echo "$add_result"
$CONTAINER_RUNTIME exec "$ALLOYDB_CONTAINER" psql -U "$ALLOYDB_USER" -d "$ALLOYDB_DB" -c \
  "SELECT google_columnar_engine_add(relation => 'products');"
$CONTAINER_RUNTIME exec "$ALLOYDB_CONTAINER" psql -U "$ALLOYDB_USER" -d "$ALLOYDB_DB" -c \
  "SELECT google_columnar_engine_add(relation => 'orders');"

if echo "$add_result" | grep -qi "No space left on device\|Insufficient shared memory"; then
  echo
  echo "❌ Ran out of /dev/shm space (a Podman container setting, not a database"
  echo "   setting). Fix: recreate the AlloyDB container with more shared memory,"
  echo "   then reload data and re-run this script:"
  echo "     ./01-setup-alloydb.sh    # creates with --shm-size=1g"
  echo "     ./04-load-sample-data.sh"
  echo "     ./06-enable-columnar-engine.sh"
  exit 1
fi

echo "==> Waiting for the background population job to finish (polling"
echo "    g_columnar_columns status — can take longer than a fixed sleep)"
for i in $(seq 1 30); do
  pending=$($CONTAINER_RUNTIME exec "$ALLOYDB_CONTAINER" psql -U "$ALLOYDB_USER" -d "$ALLOYDB_DB" -tAc \
    "SELECT count(*) FROM g_columnar_columns WHERE status <> 'Populated' AND status <> 'Usable';" 2>/dev/null || echo "?")
  if [[ "$pending" == "0" ]]; then
    echo "    all registered columns ready after ${i}s"
    break
  fi
  sleep 1
done

echo "==> Verifying what actually made it into the column store:"
$CONTAINER_RUNTIME exec "$ALLOYDB_CONTAINER" psql -U "$ALLOYDB_USER" -d "$ALLOYDB_DB" -c \
  "SELECT relation_name, column_name, status, size_in_bytes FROM g_columnar_columns ORDER BY relation_name, column_name;"

echo
echo "==> Done. Now run 07-columnar-engine-benchmark.sh for the 3-way comparison."
