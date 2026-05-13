#!/usr/bin/env bash
# Decrypt sops-encrypted secrets and render a runtime .env file.
# Usage: bash scripts/render-env-from-sops.sh [/run/hermes/.env]
#        DRY_RUN=1 bash scripts/render-env-from-sops.sh   — print actions, write nothing
# Requires: sops, age key at SOPS_AGE_KEY_FILE
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
DEST="${1:-/run/hermes/.env}"
SOPS_FILE="secrets/hermes.env.enc.yaml"

: "${SOPS_AGE_KEY_FILE:?SOPS_AGE_KEY_FILE must be set (path to age private key file)}"

if [[ ! -f "$SOPS_FILE" ]]; then
  echo "ERROR: $SOPS_FILE not found. Is this script run from the repo root?" >&2
  exit 1
fi

if grep -q "REPLACE_WITH_SOPS_ENCRYPTED_VALUE" "$SOPS_FILE" 2>/dev/null; then
  echo "ERROR: $SOPS_FILE contains placeholder values. Run sops to encrypt real secrets first." >&2
  echo "See secrets/README-age-key-bootstrap.md for setup instructions." >&2
  exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY_RUN] Would decrypt $SOPS_FILE → $DEST (chmod 600, dir mode 0700)"
  exit 0
fi

install -d -m 0700 "$(dirname "$DEST")"
umask 077
sops --decrypt --output-type dotenv "$SOPS_FILE" > "$DEST"
chmod 600 "$DEST"

echo "Rendered .env to $DEST"
