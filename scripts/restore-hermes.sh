#!/usr/bin/env bash
# Restore a Hermes data volume from an encrypted backup.
# Usage: DRY_RUN=1 bash scripts/restore-hermes.sh <backup.tar.age>
#        bash scripts/restore-hermes.sh <backup.tar.age>
# WARNING: Stops the running container. Quarantines current volume.
# Requires: docker, age private key at SOPS_AGE_KEY_FILE
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
BACKUP_FILE="${1:-}"
VOLUME_NAME="${HERMES_VOLUME:-hermes_data}"
COMPOSE_FILE="docker/docker-compose.hermes.yml"
QUARANTINE_NAME="${VOLUME_NAME}_quarantine_$(date +%s)"

run() { if [[ "$DRY_RUN" == "1" ]]; then echo "DRY: $*"; else "$@"; fi; }

if [[ -z "$BACKUP_FILE" ]]; then
  echo "Usage: $0 <backup.tar.age>" >&2
  exit 1
fi
if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi
: "${SOPS_AGE_KEY_FILE:?SOPS_AGE_KEY_FILE must be set}"

echo "=== Hermes restore ==="
echo "Backup:     $BACKUP_FILE"
echo "Volume:     $VOLUME_NAME"
echo "Quarantine: $QUARANTINE_NAME"
echo "DRY_RUN:    $DRY_RUN"
echo ""
echo "This will STOP the container and REPLACE volume data."
echo "Current data will be quarantined (NOT deleted) as: $QUARANTINE_NAME"
echo ""
if [[ "$DRY_RUN" != "1" ]]; then
  read -r -p "Type 'yes' to continue: " confirm
  [[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 0; }
fi

echo "Stopping container..."
run docker compose -f "$COMPOSE_FILE" down

echo "Quarantining current volume as $QUARANTINE_NAME..."
run docker volume create "$QUARANTINE_NAME"
if [[ "$DRY_RUN" != "1" ]]; then
  docker run --rm \
    -v "${VOLUME_NAME}:/src:ro" \
    -v "${QUARANTINE_NAME}:/dst" \
    alpine \
    sh -c "cp -a /src/. /dst/"
fi

echo "Clearing current volume..."
if [[ "$DRY_RUN" != "1" ]]; then
  docker run --rm -v "${VOLUME_NAME}:/data" alpine sh -c "find /data -mindepth 1 -delete"
fi

echo "Restoring from backup..."
if [[ "$DRY_RUN" != "1" ]]; then
  age -d -i "$SOPS_AGE_KEY_FILE" "$BACKUP_FILE" \
    | docker run --rm -i \
        -v "${VOLUME_NAME}:/restore" \
        alpine \
        tar -C /restore -xzf - --strip-components=1
fi

echo "Starting container..."
run docker compose -f "$COMPOSE_FILE" up -d

if [[ "$DRY_RUN" != "1" ]]; then
  echo "Waiting 5s for startup..."
  sleep 5
  echo "Running healthcheck..."
  bash scripts/healthcheck.sh
  echo ""
  echo "Restore complete. Quarantine volume $QUARANTINE_NAME will be auto-retained."
  echo "Delete it manually after 7 days if everything is working:"
  echo "  docker volume rm $QUARANTINE_NAME"
fi
