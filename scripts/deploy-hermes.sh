#!/usr/bin/env bash
# Deploy or redeploy the Hermes agent container.
# Usage: DRY_RUN=1 bash scripts/deploy-hermes.sh  (dry-run)
#        bash scripts/deploy-hermes.sh             (live deploy)
# Precondition: /run/hermes/.env must exist (run render-env-from-sops.sh first).
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
COMPOSE_FILE="docker/docker-compose.hermes.yml"
ENV_FILE="${HERMES_ENV_FILE:-/run/hermes/.env}"

run() { if [[ "$DRY_RUN" == "1" ]]; then echo "DRY: $*"; else "$@"; fi; }

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "ERROR: $COMPOSE_FILE not found. Run from repo root." >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Run scripts/render-env-from-sops.sh first." >&2
  exit 1
fi

echo "Pulling latest image..."
run docker compose -f "$COMPOSE_FILE" pull

echo "Starting containers..."
run docker compose -f "$COMPOSE_FILE" up -d

if [[ "$DRY_RUN" != "1" ]]; then
  echo "Waiting 5s for startup..."
  sleep 5
  echo "Running healthcheck..."
  bash scripts/healthcheck.sh
fi

echo "Deploy complete."
