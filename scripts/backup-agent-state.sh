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
CONTAINER_NAME="${CONTAINER_NAME:-${AGENT_NAME}}"
BACKUP_REPO_DIR="${BACKUP_REPO_DIR:-$HOME/state-${AGENT_NAME}}"

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

# DENYLIST POLICY (intentional choice):
# We back up EVERYTHING in /opt/data/ EXCEPT explicitly excluded items.
# This is a denylist, not an allowlist — so when Hermes adds a new
# directory, config file, hook, skill format, or any other state file in
# a future release, it is automatically backed up. The 2026-05-15 drill
# failed because the previous allowlist silently missed memories/ — we
# don't want that again.
#
# Exclude only items that fall into one of these categories:
#   - secrets    (already encrypted in sops, must not appear in plaintext repo)
#   - transient  (regenerated on container start)
#   - too-large  (sessions/, conversation history — opt-in later)
#   - sqlite-sidecar (state.db-wal/-shm — handled by atomic .backup)
EXCLUDES=(
  # secrets
  ".env"
  "auth.json"
  # transient runtime
  "logs"
  "sandboxes"
  "home"
  "bin"
  ".hermes_history"
  ".local"                          # user-level cache (uv, pip, etc.)
  # regenerable caches
  "models_dev_cache.json"
  ".skills_prompt_snapshot.json"
  "cache"
  # large / sensitive
  "sessions"
  # SQLite sidecars — atomic .backup below produces a single consistent file
  "state.db-wal"
  "state.db-shm"
  # shell defaults inherited from /etc/skel
  ".bash_logout"
  ".bashrc"
  ".profile"
  ".zshrc"
  # per-process state — NEVER backup (would resurrect a stale process state on restore)
  "auth.lock"
  "gateway.lock"
  "gateway.pid"
)

# Glob patterns (handled separately from exact-match list)
EXCLUDE_GLOBS=(
  "config.yaml.bak.*"               # wizard's own rolling config backups; redundant
)

is_excluded() {
  local item="$1"
  local ex
  for ex in "${EXCLUDES[@]}"; do
    [[ "$item" == "$ex" ]] && return 0
  done
  for ex in "${EXCLUDE_GLOBS[@]}"; do
    # shellcheck disable=SC2053  # intentional glob comparison
    [[ "$item" == $ex ]] && return 0
  done
  return 1
}

# 1a. SQLite state.db — atomic snapshot via the online backup API so a
# concurrent write can't produce a torn copy. Handled specially (not via
# the generic loop below) because it's the only file where this matters.
if docker exec "$CONTAINER_NAME" command -v sqlite3 >/dev/null 2>&1; then
  if docker exec "$CONTAINER_NAME" sqlite3 /opt/data/state.db \
       ".backup /tmp/state-snapshot.db" 2>/dev/null; then
    docker cp "${CONTAINER_NAME}:/tmp/state-snapshot.db" "${STAGING}/state.db"
    docker exec "$CONTAINER_NAME" rm -f /tmp/state-snapshot.db
  else
    log "WARN: sqlite3 .backup failed — falling back to direct copy"
    docker cp "${CONTAINER_NAME}:/opt/data/state.db" "${STAGING}/state.db" 2>/dev/null || true
  fi
else
  log "INFO: sqlite3 not in container — using plain copy (may be torn)"
  docker cp "${CONTAINER_NAME}:/opt/data/state.db" "${STAGING}/state.db" 2>/dev/null || true
fi

# 1b. Everything else in /opt/data — denylist-filtered.
# `ls -A` lists all entries including hidden files, but not . and ..
mapfile -t ITEMS < <(docker exec "$CONTAINER_NAME" sh -c 'ls -A /opt/data' 2>/dev/null)

INCLUDED=()
SKIPPED=()
for ITEM in "${ITEMS[@]}"; do
  # state.db handled above
  [[ "$ITEM" == "state.db" ]] && continue
  if is_excluded "$ITEM"; then
    SKIPPED+=("$ITEM")
    continue
  fi
  if docker cp "${CONTAINER_NAME}:/opt/data/${ITEM}" "${STAGING}/${ITEM}" 2>/dev/null; then
    INCLUDED+=("$ITEM")
  else
    log "WARN: could not copy /opt/data/${ITEM}"
  fi
done

log "Backed up (${#INCLUDED[@]}): ${INCLUDED[*]}"
log "Skipped  (${#SKIPPED[@]}): ${SKIPPED[*]}"

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
