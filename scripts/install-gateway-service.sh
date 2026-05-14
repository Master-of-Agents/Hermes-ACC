#!/usr/bin/env bash
# Install the hermes-gateway systemd service.
# Runs 'hermes gateway' inside the hermes-agent container automatically on boot.
# Usage: sudo bash scripts/install-gateway-service.sh
# Run from: anywhere (uses absolute paths)
set -euo pipefail

SERVICE_NAME="hermes-gateway"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CONTAINER_NAME="${HERMES_CONTAINER_NAME:-hermes-agent}"

echo "Installing ${SERVICE_NAME} systemd service..."

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Hermes Telegram Gateway
Documentation=https://github.com/Master-of-Agents/Hermes-ACC
After=docker.service
Requires=docker.service

[Service]
Type=simple
# Wait for the container to be running before exec-ing into it
ExecStartPre=/bin/sh -c 'until docker inspect -f "{{.State.Running}}" ${CONTAINER_NAME} 2>/dev/null | grep -q true; do sleep 2; done'
ExecStart=/usr/bin/docker exec ${CONTAINER_NAME} hermes gateway
# Restart if the gateway crashes or the container restarts (kills the exec)
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
systemctl start "${SERVICE_NAME}"

echo ""
echo "hermes-gateway service installed, enabled, and started."
echo "Check status : systemctl status hermes-gateway"
echo "View logs    : journalctl -u hermes-gateway -f"
echo "Stop gateway : systemctl stop hermes-gateway"
echo "Disable      : systemctl disable hermes-gateway"
