# Runbook: Full redeploy to a fresh VPS

**Purpose:** Rebuild the complete Hermes infrastructure on a new Hostinger VPS — planned migration, forced rebuild after VPS loss, or disaster recovery.

**Preconditions:**
- New VPS provisioned in Hostinger panel
- Operator has: SSH key pair, **offline age private key**, GitHub deploy key
- Latest backup available and integrity-verified
- `credentials/credential-registry.yaml` is current

---

## Phase 1 — Provision VPS (manual break-glass)

Follow `vps/bootstrap-notes.md` in full. Estimated time: 10–15 minutes.

Key steps:
1. Create `hermesctl` user with passwordless sudo.
2. Install operator SSH key.
3. Place GitHub deploy key at `~/.ssh/id_ed25519_hermes_acc`.
4. Harden SSH (disable root + password auth).

## Phase 2 — Bootstrap (as hermesctl)

```bash
ssh hermesctl@NEW_VPS_HOST

# Clone repo
git clone git@github.com:Master-of-Agents/Hermes-ACC.git ~/Hermes-ACC
cd ~/Hermes-ACC

# Place age key (from offline backup — see secrets/README-age-key-bootstrap.md)
mkdir -p ~/.config/sops/age
# ... paste or scp keys.txt ...
chmod 600 ~/.config/sops/age/keys.txt

# Bootstrap
DRY_RUN=1 bash scripts/bootstrap-vps.sh   # review first
bash scripts/bootstrap-vps.sh
```

## Phase 3 — Restore data from backup

```bash
# Transfer latest backup to new VPS:
scp /var/backups/hermes/hermes-<old-host>-hermes_data-<TS>.tar.age \
    hermesctl@NEW_VPS_HOST:/tmp/

# Stop container (bootstrap may have started it):
docker compose -f docker/docker-compose.hermes.yml down

# Restore:
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
bash scripts/restore-hermes.sh /tmp/hermes-<old-host>-hermes_data-<TS>.tar.age
```

## Phase 4 — Verification

Follow `checks/post-deploy-verification.md` in full.

## Phase 5 — Credential rotation (if old VPS could have been seized)

If the old VPS was lost under suspicious circumstances or could be in attacker hands:

1. Rotate `TELEGRAM_BOT_TOKEN` per `runbooks/telegram-bot-issue.md`.
2. Rotate `OPENROUTER_API_KEY` and `ANTHROPIC_API_KEY` per `runbooks/rotate-api-key.md`.
3. Rotate VPS SSH key — generate new, remove old from authorized_keys.
4. Update all `last_rotated` dates in `credentials/credential-registry.yaml`.

---

## Verification

- `bash scripts/healthcheck.sh` exits 0
- Telegram `/ping` from home chat gets a response
- Agent memory and session history intact (check a known past conversation)

## Post-conditions (docs to update)

- `inventory/servers.yaml` — update `public_ip`, `hostname` for the new host
- `vps/hostinger-<new-hostname>.md` — create a new host-specific notes file
- `vps/ssh-access-model.md` — update fingerprints
- `credentials/credential-registry.yaml` — update `last_rotated` for any rotated credentials

## Rollback

If the new VPS fails critically, re-provision and repeat from Phase 1.
The old VPS data is safe in the backup archive.
