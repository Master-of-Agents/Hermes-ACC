#!/usr/bin/env bash
# Deploy or redeploy an agent's container (defaults to atlatus).
#
# Usage:
#   bash scripts/deploy-agent.sh <agent-name>            (live deploy)
#   DRY_RUN=1 bash scripts/deploy-agent.sh <agent-name>  (dry-run)
#
# Precondition: /run/<agent-name>/.env exists
#   (run scripts/render-env-from-sops.sh <agent-name> first).
#
# Reads docker/docker-compose.<agent-name>.yml. Per docs/naming-conventions.md.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

AGENT_NAME="${1:-atlatus}"
COMPOSE_FILE="docker/docker-compose.${AGENT_NAME}.yml"
ENV_FILE="/run/${AGENT_NAME}/.env"
CONTAINER_NAME="${AGENT_NAME}"

run() { if [[ "$DRY_RUN" == "1" ]]; then echo "DRY: $*"; else "$@"; fi; }

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "ERROR: $COMPOSE_FILE not found. Run from repo root." >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Run scripts/render-env-from-sops.sh ${AGENT_NAME} first." >&2
  exit 1
fi

echo "Pulling latest image for '${AGENT_NAME}'..."
run docker compose -f "$COMPOSE_FILE" pull

echo "Starting container '${CONTAINER_NAME}'..."
run docker compose -f "$COMPOSE_FILE" up -d

if [[ "$DRY_RUN" != "1" ]]; then
  echo "Waiting 5s for startup..."
  sleep 5
  echo "Running healthcheck..."
  HERMES_CONTAINER_NAME="$CONTAINER_NAME" bash scripts/healthcheck.sh
fi

echo "Deploy complete."
