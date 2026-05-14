#!/usr/bin/env bash
# End-to-end VPS bootstrap after manual break-glass steps are complete.
# See vps/bootstrap-notes.md for the manual prerequisite steps.
# Usage: DRY_RUN=1 bash scripts/bootstrap-vps.sh
# Run as: hermesctl (with passwordless sudo)
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
REPO_DIR="${REPO_DIR:-$HOME/Hermes-ACC}"
HERMES_PORT_HOST="${HERMES_PORT_HOST:-32768}"

run() { if [[ "$DRY_RUN" == "1" ]]; then echo "DRY: $*"; else "$@"; fi; }

echo "=== Hermes-ACC VPS Bootstrap ==="
echo "DRY_RUN: $DRY_RUN"
echo ""

# --- System packages ---
echo "[1/7] Installing system packages..."
run sudo apt-get update -qq
run sudo apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release git jq netcat-openbsd

# Install yq for YAML parsing in scripts
if ! command -v yq &>/dev/null; then
  YQ_VERSION="4.44.1"
  echo "Installing yq ${YQ_VERSION}..."
  run sudo curl -fsSL \
    "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
    -o /usr/local/bin/yq
  run sudo chmod +x /usr/local/bin/yq
fi

# --- Docker ---
echo "[2/7] Installing Docker..."
run bash "${REPO_DIR}/scripts/install-docker.sh"
# newgrp is intentionally omitted: it hangs in a non-interactive script context.
# hermesctl must already be in the docker group before running this script
# (ensured by break-glass Step 2). A new login session picks up group membership.

# --- sops + age ---
echo "[3/7] Installing sops + age..."
run bash "${REPO_DIR}/scripts/install-sops-age.sh"

# --- UFW ---
echo "[4/7] Configuring UFW firewall..."
run sudo ufw default deny incoming
run sudo ufw default allow outgoing
run sudo ufw allow 22/tcp comment 'ssh'
run sudo ufw allow "${HERMES_PORT_HOST}/tcp" comment 'hermes-agent'
run sudo ufw --force enable
run sudo ufw status verbose

# --- age key check ---
echo "[5/7] Checking age private key..."
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
if [[ ! -f "$AGE_KEY_FILE" ]]; then
  echo "ERROR: Age private key not found at $AGE_KEY_FILE" >&2
  echo "See secrets/README-age-key-bootstrap.md to bootstrap the age key." >&2
  exit 1
fi
echo "Age key found at $AGE_KEY_FILE"

# --- Render .env ---
echo "[6/7] Rendering runtime .env from sops..."
export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"
run bash "${REPO_DIR}/scripts/render-env-from-sops.sh" /run/hermes/.env

# --- Deploy ---
echo "[7/8] Deploying Hermes container..."
run bash "${REPO_DIR}/scripts/deploy-hermes.sh"

# --- Gateway service (conditional on Hermes wizard being completed) ---
echo "[8/8] Checking for Hermes agent config..."
if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY: would check for /opt/data/config.yaml in container and install hermes-gateway.service if present"
elif docker exec hermes-agent test -f /opt/data/config.yaml 2>/dev/null; then
  echo "Hermes config detected — installing hermes-gateway systemd service..."
  sudo bash "${REPO_DIR}/scripts/install-gateway-service.sh"
else
  echo ""
  echo "  Hermes setup wizard has not been run yet."
  echo "  The gateway systemd service will NOT be installed at this point."
  echo ""
  echo "  Next steps:"
  echo "    1. Open http://<VPS_IP>:${HERMES_PORT_HOST} in a browser"
  echo "    2. Complete the wizard (see hermes/wizard-choices.md)"
  echo "    3. Run: sudo bash ${REPO_DIR}/scripts/install-gateway-service.sh"
  echo ""
  echo "  See runbooks/post-bootstrap-agent-setup.md for the full procedure."
fi

echo ""
echo "=== Bootstrap complete. ==="
echo "Run checks/post-deploy-verification.md for final verification steps."
