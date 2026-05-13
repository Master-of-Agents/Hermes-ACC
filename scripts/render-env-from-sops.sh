#!/usr/bin/env bash
# Decrypt sops-encrypted secrets and render a runtime .env file.
# Usage: bash scripts/render-env-from-sops.sh [/run/hermes/.env]
# Requires: sops, age key at SOPS_AGE_KEY_FILE
set -euo pipefail

DEST="${1:-/run/hermes/.env}"
SOPS_FILE="secrets/hermes.env.enc.yaml"

: "${SOPS_AGE_KEY_FILE:?SOPS_AGE_KEY_FILE must be set (path to age private key file)}"

if [[ ! -f "$SOPS_FILE" ]]; then
  echo "ERROR: $SOPS_FILE not found. Is this script run from the repo root?" >&2
  exit 1
fi

if [[ "$SOPS_FILE" == *"REPLACE_WITH_SOPS"* ]] || grep -q "REPLACE_WITH_SOPS_ENCRYPTED_VALUE" "$SOPS_FILE" 2>/dev/null; then
  echo "ERROR: $SOPS_FILE contains placeholder values. Run sops to encrypt real secrets first." >&2
  echo "See secrets/README-age-key-bootstrap.md for setup instructions." >&2
  exit 1
fi

install -d -m 0700 "$(dirname "$DEST")"
umask 077
sops --decrypt --output-type dotenv "$SOPS_FILE" > "$DEST"
chmod 600 "$DEST"

echo "Rendered .env to $DEST"
