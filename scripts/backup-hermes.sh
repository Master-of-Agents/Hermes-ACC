#!/usr/bin/env bash
# Create an encrypted backup of the Hermes agent data volume.
# Usage: DRY_RUN=1 bash scripts/backup-hermes.sh  (dry-run)
#        bash scripts/backup-hermes.sh             (live backup)
# Output: /var/backups/hermes/hermes-<host>-hermes_data-<timestamp>.tar.age
# Requires: docker, age (recipient public key in inventory/servers.yaml)
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
VOLUME_NAME="${HERMES_VOLUME:-hermes_data}"
OUT_DIR="${BACKUP_DIR:-/var/backups/hermes}"
HOST="$(hostname -s)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_FILE="${OUT_DIR}/hermes-${HOST}-${VOLUME_NAME}-${TS}.tar.age"

run() { if [[ "$DRY_RUN" == "1" ]]; then echo "DRY: $*"; else "$@"; fi; }

# Read recipient public key from inventory
if command -v yq &>/dev/null; then
  RECIPIENT="$(yq '.servers[] | select(.id == "'"$HOST"'") | .backup_recipient_age_public' inventory/servers.yaml 2>/dev/null || true)"
fi
if [[ -z "${RECIPIENT:-}" ]]; then
  RECIPIENT="${AGE_RECIPIENT:-}"
fi
if [[ -z "$RECIPIENT" ]]; then
  echo "ERROR: No age recipient public key found." >&2
  echo "  Set AGE_RECIPIENT env var or add backup_recipient_age_public to inventory/servers.yaml." >&2
  exit 1
fi

if [[ "$RECIPIENT" == *"REPLACE_WITH"* ]]; then
  echo "ERROR: inventory/servers.yaml still has a placeholder age public key." >&2
  exit 1
fi

echo "Backing up volume: $VOLUME_NAME → $OUT_FILE"
run install -d -m 0700 "$OUT_DIR"

if [[ "$DRY_RUN" != "1" ]]; then
  docker run --rm \
    -v "${VOLUME_NAME}:/data:ro" \
    alpine \
    tar -C / -czf - data \
    | age -r "$RECIPIENT" -o "$OUT_FILE"

  # Verify the archive is readable (integrity check)
  age -d -i "${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" "$OUT_FILE" | tar -tzf - > /dev/null
  echo "Backup verified: $OUT_FILE"
else
  echo "DRY: docker run ... | age -r $RECIPIENT -o $OUT_FILE"
fi
