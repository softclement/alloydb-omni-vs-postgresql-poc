#!/usr/bin/env bash
# 99-cleanup.sh — tear the whole 3-engine PoC down. Safe to re-run.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-env.sh

echo "==> Stopping and removing containers"
$CONTAINER_RUNTIME rm -f "$ALLOYDB_CONTAINER" >/dev/null 2>&1 || true
$CONTAINER_RUNTIME rm -f "$PG17_CONTAINER"    >/dev/null 2>&1 || true
$CONTAINER_RUNTIME rm -f "$PG19_CONTAINER"    >/dev/null 2>&1 || true

read -r -p "Also remove the pulled images (${ALLOYDB_IMAGE}, ${PG17_IMAGE}, ${PG19_IMAGE})? [y/N] " ans
if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
  $CONTAINER_RUNTIME rmi -f "$ALLOYDB_IMAGE" >/dev/null 2>&1 || true
  $CONTAINER_RUNTIME rmi -f "$PG17_IMAGE"    >/dev/null 2>&1 || true
  $CONTAINER_RUNTIME rmi -f "$PG19_IMAGE"    >/dev/null 2>&1 || true
  echo "==> Images removed"
fi

read -r -p "Also delete captured results in $RESULTS_DIR? [y/N] " ans2
if [[ "${ans2:-N}" =~ ^[Yy]$ ]]; then
  rm -rf "${RESULTS_DIR:?}"/*
  echo "==> Results cleared"
fi

echo "==> Cleanup complete. Environment is back to a clean slate."
