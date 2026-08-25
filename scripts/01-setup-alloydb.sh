#!/usr/bin/env bash
# 01-setup-alloydb.sh — pull and start AlloyDB Omni in rootful Podman
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-env.sh

echo "==> Pulling ${ALLOYDB_IMAGE}"
$CONTAINER_RUNTIME pull "$ALLOYDB_IMAGE"

echo "==> Removing any previous ${ALLOYDB_CONTAINER} container"
$CONTAINER_RUNTIME rm -f "$ALLOYDB_CONTAINER" >/dev/null 2>&1 || true

echo "==> Starting ${ALLOYDB_CONTAINER} on host port ${ALLOYDB_PORT}"
# --shm-size matters: the columnar engine builds its column store in
# /dev/shm, and Podman's 64MB default fails with "could not resize shared
# memory segment ... No space left on device" the moment you populate it.
$CONTAINER_RUNTIME run --name "$ALLOYDB_CONTAINER" \
  -e POSTGRES_PASSWORD="$ALLOYDB_PASSWORD" \
  -p "${ALLOYDB_PORT}:5432" \
  --shm-size="$ALLOYDB_SHM_SIZE" \
  -d "$ALLOYDB_IMAGE"

echo "==> Waiting for AlloyDB Omni to accept connections..."
wait_for_pg_ready "$ALLOYDB_CONTAINER" "$ALLOYDB_USER"

echo "==> Creating PoC database '${ALLOYDB_DB}'"
ensure_db "$ALLOYDB_CONTAINER" "$ALLOYDB_USER" "$ALLOYDB_DB"

echo "==> AlloyDB Omni is up: psql -h localhost -p ${ALLOYDB_PORT} -U ${ALLOYDB_USER} -d ${ALLOYDB_DB}"
