#!/usr/bin/env bash
# 02-setup-vanilla-pg17.sh — the FAIR baseline: same PostgreSQL major.minor
# (17.9) that AlloyDB Omni is currently built on. This is the container to
# compare AlloyDB against when you want to isolate the AlloyDB engine's own
# improvements from core PostgreSQL version drift.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-env.sh

echo "==> Pulling ${PG17_IMAGE}"
$CONTAINER_RUNTIME pull "$PG17_IMAGE"

echo "==> Removing any previous ${PG17_CONTAINER} container"
$CONTAINER_RUNTIME rm -f "$PG17_CONTAINER" >/dev/null 2>&1 || true

echo "==> Starting ${PG17_CONTAINER} on host port ${PG17_PORT}"
$CONTAINER_RUNTIME run --name "$PG17_CONTAINER" \
  -e POSTGRES_PASSWORD="$PG17_PASSWORD" \
  -p "${PG17_PORT}:5432" \
  -d "$PG17_IMAGE"

echo "==> Waiting for PostgreSQL 17.9 to accept connections..."
wait_for_pg_ready "$PG17_CONTAINER" "$PG17_USER"

echo "==> Creating PoC database '${PG17_DB}'"
ensure_db "$PG17_CONTAINER" "$PG17_USER" "$PG17_DB"

echo "==> PostgreSQL 17.9 is up: psql -h localhost -p ${PG17_PORT} -U ${PG17_USER} -d ${PG17_DB}"
