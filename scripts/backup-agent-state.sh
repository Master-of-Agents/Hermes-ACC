#!/usr/bin/env bash
# Back up the agent's identity-defining state to its dedicated GitHub repo.
#
# This script:
#   1. Copies the agent's individual data out of the hermes-agent container
#   2. Redacts API keys from config.yaml
#   3. Commits the snapshot to the agent's state repo
#   4. Pushes to GitHub
#
# Designed to be run hourly via systemd timer (see install-backup-timer.sh).
#
# Environment overrides:
#   AGENT_NAME       — defaults to "atlatus"
#   CONTAINER_NAME   — defaults to "hermes-agent"
#   BACKUP_REPO_DIR  — defaults to "$HOME/hermes-state-${AGENT_NAME}"
#
# Exit codes:
#   0  — backup committed and pushed (or no changes to commit)
#   1  — container not running
#   2  — local working tree missing or corrupt
#   3  — git push failed
set -euo pipefail

AGENT_NAME="${AGENT_NAME:-atlatus}"
CONTAINER_NAME="${CONTAINER_NAME:-hermes-agent}"
BACKUP_REPO_DIR="${BACKUP_REPO_DIR:-$HOME/hermes-state-${AGENT_NAME}}"

log() { echo "[backup-agent-state] $(date -u +%H:%M:%S) $*"; }

# --- Preconditions ---
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; then
  log "ERROR: container $CONTAINER_NAME is not running"
  exit 1
fi

if [[ ! -d "$BACKUP_REPO_DIR/.git" ]]; then
  log "ERROR: backup repo working tree not found at $BACKUP_REPO_DIR"
  log "Run install-backup-timer.sh first to provision it."
  exit 2
fi

log "Snapshotting agent state for '$AGENT_NAME' from $CONTAINER_NAME..."

# --- Stage 1: copy raw files out of the container ---
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

# Individual identity files — copy whatever exists; skip the rest quietly.
for ITEM in SOUL.md skills cron state.db config.yaml; do
  if docker exec "$CONTAINER_NAME" test -e "/opt/data/${ITEM}" 2>/dev/null; then
    docker cp "${CONTAINER_NAME}:/opt/data/${ITEM}" "${STAGING}/${ITEM}" 2>/dev/null || \
      log "WARN: could not copy /opt/data/${ITEM}"
  fi
done

# --- Stage 2: redact secrets from config.yaml ---
# Match `api_key: "..."` and `api_key: ...` patterns regardless of quoting.
# Replace any non-empty value with the literal string REDACTED.
if [[ -f "$STAGING/config.yaml" ]]; then
  python3 - "$STAGING/config.yaml" << 'PY'
import re, sys
p = sys.argv[1]
with open(p, encoding="utf-8") as f:
    text = f.read()
# Redact any api_key: <non-empty-value> on a single line.
# Keeps `api_key: ''` and `api_key: ""` untouched (they're already empty).
redacted = re.sub(
    r'(^\s*api_key:\s*)(?!(?:""|\'\'|null|~|\s*$))(.+)$',
    r'\1REDACTED',
    text,
    flags=re.MULTILINE,
)
with open(p, "w", encoding="utf-8") as f:
    f.write(redacted)
PY
fi

# Drop the cron output/ subdir — it's per-run noise, not state.
[[ -d "$STAGING/cron/output" ]] && rm -rf "$STAGING/cron/output"

# --- Stage 3: sync into the backup repo working tree ---
# Use rsync with --delete so removed files (e.g. deleted skills) disappear too.
rsync -a --delete \
  --exclude='.git' \
  --exclude='README.md' \
  "$STAGING/" "$BACKUP_REPO_DIR/"

# --- Stage 4: commit + push ---
cd "$BACKUP_REPO_DIR"

git add -A
if git diff --cached --quiet; then
  log "No state changes since last backup — skipping commit."
  exit 0
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
git -c user.name="hermes-backup-bot" \
    -c user.email="backup@${AGENT_NAME}.local" \
    commit -m "snapshot ${TS}" >/dev/null

if ! git push origin HEAD 2>&1 | tee /tmp/backup-agent-state-push.log; then
  log "ERROR: git push failed — see /tmp/backup-agent-state-push.log"
  exit 3
fi

log "Backup committed and pushed: ${TS}"
