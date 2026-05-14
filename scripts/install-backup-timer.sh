#!/usr/bin/env bash
# One-shot installer for the agent-state backup pipeline.
#
# Does three things:
#   1. Configures SSH so the agent's backup deploy key reaches its state repo
#   2. Clones the backup repo to a working directory on the VPS
#   3. Installs and starts the systemd timer that runs backup-agent-state.sh hourly
#
# Idempotent: rerun to update the timer unit or reconfigure SSH.
# Run as the operator user (hermesctl), not root. Sudo is used internally
# only for systemd unit installation.
#
# Required env vars (no defaults — fail fast if missing):
#   AGENT_NAME       — short agent name used in repo/key paths (e.g. atlatus)
#   GITHUB_ORG       — the GitHub org or user owning the state repo
#
# Optional:
#   STATE_KEY_FILE   — defaults to ~/.ssh/id_ed25519_hermes_state_${AGENT_NAME}
#   BACKUP_REPO_DIR  — defaults to ~/hermes-state-${AGENT_NAME}
set -euo pipefail

: "${AGENT_NAME:?AGENT_NAME must be set (e.g. AGENT_NAME=atlatus)}"
: "${GITHUB_ORG:?GITHUB_ORG must be set (e.g. GITHUB_ORG=Master-of-Agents)}"

REPO_NAME="hermes-state-${AGENT_NAME}"
STATE_KEY_FILE="${STATE_KEY_FILE:-$HOME/.ssh/id_ed25519_hermes_state_${AGENT_NAME}}"
BACKUP_REPO_DIR="${BACKUP_REPO_DIR:-$HOME/${REPO_NAME}}"
SSH_HOST_ALIAS="github.com-${REPO_NAME}"
ACC_REPO_DIR="${ACC_REPO_DIR:-$HOME/Hermes-ACC}"
SERVICE_NAME="hermes-backup-${AGENT_NAME}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TIMER_FILE="/etc/systemd/system/${SERVICE_NAME}.timer"

echo "Installing backup pipeline for agent '${AGENT_NAME}' (repo: ${GITHUB_ORG}/${REPO_NAME})..."

# --- 1. SSH config ---
if [[ ! -f "$STATE_KEY_FILE" ]]; then
  echo "ERROR: backup deploy key not found at $STATE_KEY_FILE" >&2
  echo "Generate it with: ssh-keygen -t ed25519 -f $STATE_KEY_FILE -N ''" >&2
  exit 1
fi

SSH_CONFIG="$HOME/.ssh/config"
touch "$SSH_CONFIG" && chmod 600 "$SSH_CONFIG"

if ! grep -q "^Host ${SSH_HOST_ALIAS}$" "$SSH_CONFIG"; then
  echo "Adding SSH host alias '${SSH_HOST_ALIAS}' to $SSH_CONFIG..."
  cat >> "$SSH_CONFIG" << EOF

Host ${SSH_HOST_ALIAS}
  HostName github.com
  User git
  IdentityFile ${STATE_KEY_FILE}
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
EOF
else
  echo "SSH host alias '${SSH_HOST_ALIAS}' already configured."
fi

# --- 2. Clone the backup repo ---
if [[ ! -d "${BACKUP_REPO_DIR}/.git" ]]; then
  echo "Cloning ${GITHUB_ORG}/${REPO_NAME} to ${BACKUP_REPO_DIR}..."
  git clone "git@${SSH_HOST_ALIAS}:${GITHUB_ORG}/${REPO_NAME}.git" "$BACKUP_REPO_DIR"
else
  echo "Backup repo already cloned at ${BACKUP_REPO_DIR}."
fi

# --- 3. Install the systemd service + timer ---
echo "Installing systemd unit ${SERVICE_NAME}.service and timer..."

sudo tee "$SERVICE_FILE" >/dev/null << EOF
[Unit]
Description=Hermes agent state backup (${AGENT_NAME})
Documentation=https://github.com/Master-of-Agents/Hermes-ACC
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$(id -un)
Group=$(id -gn)
WorkingDirectory=${ACC_REPO_DIR}
Environment="AGENT_NAME=${AGENT_NAME}"
Environment="BACKUP_REPO_DIR=${BACKUP_REPO_DIR}"
ExecStart=/bin/bash ${ACC_REPO_DIR}/scripts/backup-agent-state.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

sudo tee "$TIMER_FILE" >/dev/null << EOF
[Unit]
Description=Run Hermes agent state backup hourly (${AGENT_NAME})

[Timer]
OnCalendar=hourly
# Run on boot if we missed any while powered off
Persistent=true
# Small random delay to avoid spike-of-N agents pushing at once
RandomizedDelaySec=120
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "${SERVICE_NAME}.timer"

echo ""
echo "Backup pipeline installed."
echo "  Repo dir   : ${BACKUP_REPO_DIR}"
echo "  Timer      : ${SERVICE_NAME}.timer (hourly)"
echo ""
echo "Run an immediate backup : sudo systemctl start ${SERVICE_NAME}.service"
echo "View next firing time   : systemctl list-timers ${SERVICE_NAME}.timer"
echo "View logs               : journalctl -u ${SERVICE_NAME}.service -f"
echo "Stop the timer          : sudo systemctl disable --now ${SERVICE_NAME}.timer"
