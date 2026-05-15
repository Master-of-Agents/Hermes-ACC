#!/usr/bin/env bash
# Decrypt sops-encrypted secrets for an agent and render a runtime .env file.
#
# Usage:
#   bash scripts/render-env-from-sops.sh <agent-name> [/run/<agent-name>/.env]
#   DRY_RUN=1 bash scripts/render-env-from-sops.sh <agent-name>
#
# Defaults:
#   <agent-name>  — must be provided (no default — fail fast)
#   destination   — /run/<agent-name>/.env
#
# Reads secrets/<agent-name>.env.enc.yaml (per docs/naming-conventions.md).
# Requires sops and the age key at SOPS_AGE_KEY_FILE.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

AGENT_NAME="${1:-}"
if [[ -z "$AGENT_NAME" ]]; then
  echo "ERROR: agent name is required as the first argument." >&2
  echo "Usage: bash $0 <agent-name> [/run/<agent-name>/.env]" >&2
  exit 1
fi

DEST="${2:-/run/${AGENT_NAME}/.env}"
SOPS_FILE="secrets/${AGENT_NAME}.env.enc.yaml"

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

sudo install -d -m 0700 -o "$(id -un)" -g "$(id -gn)" "$(dirname "$DEST")"
umask 077
sops --decrypt --output-type dotenv "$SOPS_FILE" > "$DEST"
chmod 600 "$DEST"

echo "Rendered .env to $DEST"
