#!/usr/bin/env bash
# 03-setup-vanilla-pg19beta3.sh — the BONUS track: two major versions ahead
# of AlloyDB Omni's base. Keep numbers from this container on a separate
# slide from the AlloyDB comparison — see README "Version caveat".
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-env.sh

echo "==> Pulling ${PG19_IMAGE}"
$CONTAINER_RUNTIME pull "$PG19_IMAGE"

echo "==> Removing any previous ${PG19_CONTAINER} container"
$CONTAINER_RUNTIME rm -f "$PG19_CONTAINER" >/dev/null 2>&1 || true

echo "==> Starting ${PG19_CONTAINER} on host port ${PG19_PORT}"
$CONTAINER_RUNTIME run --name "$PG19_CONTAINER" \
  -e POSTGRES_PASSWORD="$PG19_PASSWORD" \
  -p "${PG19_PORT}:5432" \
  -d "$PG19_IMAGE"

echo "==> Waiting for PostgreSQL 19 Beta 3 to accept connections..."
wait_for_pg_ready "$PG19_CONTAINER" "$PG19_USER"

echo "==> Creating PoC database '${PG19_DB}'"
ensure_db "$PG19_CONTAINER" "$PG19_USER" "$PG19_DB"

echo "==> PostgreSQL 19 Beta 3 is up: psql -h localhost -p ${PG19_PORT} -U ${PG19_USER} -d ${PG19_DB}"
