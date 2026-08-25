#!/usr/bin/env bash
# 00-env.sh — shared settings for the 3-way PoC:
#   AlloyDB Omni 17.9  vs  vanilla PostgreSQL 17.9  vs  vanilla PostgreSQL 19 Beta 3
# Source this file from every other script: `source ./00-env.sh`

set -euo pipefail

export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-sudo podman}"

# --- AlloyDB Omni (currently tracks PostgreSQL 17.9) -----------------------
export ALLOYDB_CONTAINER="${ALLOYDB_CONTAINER:-alloydb-omni}"
export ALLOYDB_IMAGE="${ALLOYDB_IMAGE:-docker.io/google/alloydbomni:latest}"
export ALLOYDB_PORT="${ALLOYDB_PORT:-5434}"
export ALLOYDB_USER="${ALLOYDB_USER:-postgres}"
export ALLOYDB_PASSWORD="${ALLOYDB_PASSWORD:-Passw0rd!}"
export ALLOYDB_DB="${ALLOYDB_DB:-pocdb}"
export ALLOYDB_SHM_SIZE="${ALLOYDB_SHM_SIZE:-1g}"

# --- Vanilla PostgreSQL 17.9 — SAME major.minor as AlloyDB Omni above ------
# This is the fair, apples-to-apples engine comparison: same PostgreSQL
# version underneath, so any timing difference is genuinely the AlloyDB
# engine, not core PostgreSQL version drift.
export PG17_CONTAINER="${PG17_CONTAINER:-pg17}"
export PG17_IMAGE="${PG17_IMAGE:-docker.io/library/postgres:17.9}"
export PG17_PORT="${PG17_PORT:-5433}"
export PG17_USER="${PG17_USER:-postgres}"
export PG17_PASSWORD="${PG17_PASSWORD:-Passw0rd!}"
export PG17_DB="${PG17_DB:-pocdb}"

# --- Vanilla PostgreSQL 19 Beta 3 — bonus "what's coming next" track -------
# Two major versions ahead of AlloyDB Omni's base — keep any numbers from
# this container in a SEPARATE slide from the AlloyDB comparison, not
# blended with it. See README "Version caveat".
export PG19_CONTAINER="${PG19_CONTAINER:-pg19beta3}"
export PG19_IMAGE="${PG19_IMAGE:-docker.io/library/postgres:19beta3}"
export PG19_PORT="${PG19_PORT:-5436}"
export PG19_USER="${PG19_USER:-postgres}"
export PG19_PASSWORD="${PG19_PASSWORD:-Passw0rd!}"
export PG19_DB="${PG19_DB:-pocdb}"

# --- Shared PoC working directory ------------------------------------------
export POC_HOME="${POC_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export RESULTS_DIR="${RESULTS_DIR:-$POC_HOME/results}"
export SQL_DIR="${SQL_DIR:-$POC_HOME/sql}"
mkdir -p "$RESULTS_DIR"

# --- Shared helpers ----------------------------------------------------
# Official postgres-based images (including AlloyDB Omni) do an internal
# initdb -> temporary startup -> run init scripts -> SHUTDOWN -> real
# startup cycle on first boot. A single pg_isready success can land in
# that temporary window right before the shutdown. These helpers wait for
# pg_isready to succeed several times in a row before trusting it.

wait_for_pg_ready () {
  # wait_for_pg_ready <container> <user>
  local container="$1" user="$2"
  local consecutive=0 required=3 attempt
  for attempt in $(seq 1 60); do
    if $CONTAINER_RUNTIME exec "$container" pg_isready -U "$user" >/dev/null 2>&1; then
      consecutive=$((consecutive + 1))
      if [[ "$consecutive" -ge "$required" ]]; then
        echo "    ready and stable after ~${attempt}s"
        return 0
      fi
    else
      consecutive=0
    fi
    sleep 1
  done
  echo "    WARNING: never reached a stable ready state after 60s — continuing anyway"
  return 1
}

retry_cmd () {
  # retry_cmd <description> -- <command...>
  local desc="$1"; shift
  [[ "$1" == "--" ]] && shift
  local attempt
  for attempt in $(seq 1 10); do
    if "$@"; then
      return 0
    fi
    echo "    [$desc] attempt ${attempt} failed, retrying in 2s..."
    sleep 2
  done
  echo "    [$desc] failed after 10 attempts"
  return 1
}

ensure_db () {
  # ensure_db <container> <user> <db>
  local container="$1" user="$2" db="$3"
  if $CONTAINER_RUNTIME exec "$container" psql -U "$user" -tAc \
    "SELECT 1 FROM pg_database WHERE datname = '${db}'" 2>/dev/null | grep -q 1; then
    echo "    '${db}' already exists, skipping"
  else
    retry_cmd "creating database ${db}" -- \
      $CONTAINER_RUNTIME exec "$container" createdb -U "$user" "$db"
  fi
}
