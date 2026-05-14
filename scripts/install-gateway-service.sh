#!/usr/bin/env bash
# Install the hermes-gateway systemd service.
#
# Service responsibilities (in order, on every start):
#   1. Render /run/hermes/.env from sops-encrypted secrets
#   2. Ensure the hermes-agent container is running with current env_file
#   3. Wait for the container to be in Running state
#   4. Run `hermes gateway` inside the container (as the hermes user)
#
# Idempotent: re-running this script updates the unit file in place.
# Usage: sudo bash scripts/install-gateway-service.sh
set -euo pipefail

SERVICE_NAME="hermes-gateway"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CONTAINER_NAME="${HERMES_CONTAINER_NAME:-hermes-agent}"
REPO_DIR="${REPO_DIR:-/home/hermesctl/Hermes-ACC}"
AGE_KEY_FILE="${AGE_KEY_FILE:-/home/hermesctl/.config/sops/age/keys.txt}"
COMPOSE_FILE="${REPO_DIR}/docker/docker-compose.hermes.yml"

echo "Installing ${SERVICE_NAME} systemd service..."

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Hermes Telegram Gateway
Documentation=https://github.com/Master-of-Agents/Hermes-ACC
After=docker.service local-fs.target
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=${REPO_DIR}
Environment="SOPS_AGE_KEY_FILE=${AGE_KEY_FILE}"

# 1. Render the runtime .env from sops (idempotent — overwrites if already present)
ExecStartPre=/bin/bash ${REPO_DIR}/scripts/render-env-from-sops.sh /run/hermes/.env

# 2. Ensure the container is running with the current env_file
ExecStartPre=/usr/bin/docker compose -f ${COMPOSE_FILE} up -d

# 3. Wait for the container to be in Running state
ExecStartPre=/bin/sh -c 'until docker inspect -f "{{.State.Running}}" ${CONTAINER_NAME} 2>/dev/null | grep -q true; do sleep 2; done'

# 4. Run the gateway as the hermes user inside the container.
# --replace ensures we take over any pre-existing gateway instance (manual or
# stale from a previous service incarnation).
ExecStart=/usr/bin/docker exec -u hermes ${CONTAINER_NAME} hermes gateway run --replace

# Restart the gateway (and pre-steps) on failure or container restart
Restart=on-failure
RestartSec=15
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hermes-gateway

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

echo ""
echo "${SERVICE_NAME} service installed, enabled, and started."
echo ""
echo "Pre-start steps run automatically:"
echo "  1. Renders /run/hermes/.env from sops"
echo "  2. Brings up the container via docker compose"
echo "  3. Waits for container Running state"
echo "  4. Starts the gateway as the hermes user"
echo ""
echo "Check status : systemctl status ${SERVICE_NAME}"
echo "View logs    : journalctl -u ${SERVICE_NAME} -f"
echo "Stop gateway : systemctl stop ${SERVICE_NAME}"
echo "Disable      : systemctl disable ${SERVICE_NAME}"
