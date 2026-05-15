# Runbook: Periodic maintenance

**Purpose:** Routine housekeeping tasks that aren't urgent but accumulate
costs if neglected. None of these are "the bot is broken" — they're
"things degrade if no one ever does this."

**How to use this runbook:** check it during quiet sessions when there's
nothing else demanding attention, or when something else triggers a
reminder ("disk's getting full," "haven't run a drill recently," "that
key feels old"). Each entry is independent — you can do one and skip the
rest.

---

## Cadence overview

| Cadence | Items |
|---|---|
| Every 2–3 months | Reclaim Docker disk space (image prune) |
| Every 60–90 days | Disaster recovery drill |
| Every 6–12 months | Age key rotation, operator SSH key rotation, GitHub deploy key rotation |
| Ad-hoc | Disk pressure spike (>80%), log volume audit |

---

## 1. Reclaim Docker disk space

**Why:** every `docker compose pull` that brings a new image version
leaves the previous version behind as a tagged-but-detached image plus
its containerd overlay snapshots. On a single-agent VPS that's ~10 GB
of drift over a year; with multiple agents it grows proportionally.

**Symptoms it's needed:** `df -h /` showing creeping `Use%`, or just
calendar time since last cleanup.

**Procedure:**

```bash
# 1. See current state
df -h /
docker system df

# 2. Prune all unused images. (Active image stays — we have one running container.)
docker image prune -a
# Type 'y' when prompted

# 3. Verify
df -h /
docker system df
```

**Expected reclaim:** roughly the size of one container image per
release pulled (the Hostinger Hermes image is ~10 GB), times the number
of versions you've cycled through.

**Safe to do anytime** — only touches images with no associated
container. Atlatus stays running.

### Automated alternative

If manual feels too frequent, drop a weekly cron:

```bash
sudo tee /etc/cron.weekly/docker-image-prune > /dev/null << 'EOF'
#!/bin/sh
# Weekly Docker image cleanup — keeps /var from creeping over time.
/usr/bin/docker image prune -af >/dev/null 2>&1
EOF
sudo chmod +x /etc/cron.weekly/docker-image-prune
```

Trade-off: silent automation vs. the awareness gained from running it
manually. Single-agent VPS today: manual is fine. After agent #2+:
revisit.

---

## 2. Disaster recovery drill

**Why:** every change to bootstrap scripts, runbooks, or backup logic
risks introducing a regression. Drills are the only way to catch them
before a real disaster does.

**When:**
- 60–90 days since the last drill
- After any significant change to `runbooks/new-vps-from-zero.md`,
  `scripts/bootstrap-vps.sh`, `scripts/backup-agent-state.sh`,
  `scripts/install-gateway-service.sh`, or `scripts/install-backup-timer.sh`
- After upgrading the Hermes container image to a substantially new
  version

**Procedure:** run `runbooks/new-vps-from-zero.md` end-to-end on the
drill VPS (`srv1670888`). Log findings to `runbooks/drill-log.md`.

**Target time:** under 60 minutes. If it took longer, the runbook has
friction that the next drill should remove.

---

## 3. Credential rotations

| Credential | Cadence | Procedure |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` (per agent) | Annual or on suspected leak | `runbooks/telegram-bot-issue.md` |
| `XAI_API_KEY` | Annual | `runbooks/rotate-api-key.md` |
| Operator SSH key (per VPS) | Annual | `vps/ssh-access-model.md → Key rotation procedure` |
| GitHub deploy key (Hermes-ACC, per VPS) | Annual | Same — regenerate, replace on repo, update fingerprint in registry |
| GitHub state-backup deploy key (per agent) | Annual | `vps/ssh-access-model.md → Key rotation procedure` |
| Primary age key | Annual or on suspected leak | `runbooks/lost-age-key.md → Option A` (uses the recovery identity) |
| Recovery age key | Annual or on suspected leak | Same flow as primary, plus regenerate the offline backup |

After every rotation: update `last_rotated` in
`credentials/credential-registry.yaml` and commit.

---

## 4. Ad-hoc — disk pressure spike

**Symptom:** `df -h /` shows `Use%` above ~80%.

**Order of operations:**

1. **Where is it?**
   ```bash
   sudo du -h --max-depth=1 / 2>/dev/null | sort -h | tail -10
   ```
   Usually `/var/lib/docker` or `/var/lib/containerd`.

2. **Docker accounting**
   ```bash
   docker system df
   ```
   If `Reclaimable` is significant → item #1 above.

3. **Agent volume bloat**
   ```bash
   sudo du -h --max-depth=2 /var/lib/docker/volumes/data-<agent>/_data 2>/dev/null | sort -h | tail
   ```
   Common offenders inside an agent:
   - `sessions/` — conversation history, grows forever unless pruned via
     Hermes's own `sessions.auto_prune` config setting
   - `cache/` — model dev cache, safe to clear; agent regenerates
   - `images/` — files the agent processed; review and prune manually

4. **Log volume**
   ```bash
   sudo journalctl --disk-usage
   sudo journalctl --vacuum-time=7d   # keep only 7 days
   ```
   The Docker container logs themselves are already capped (10 MB × 5
   files per container in `docker-compose.<agent>.yml`), so they
   shouldn't be the culprit — but worth a glance.

---

## 5. Ad-hoc — log volume audit

**Cadence:** annually, or when investigating an issue.

**Verify caps are still in effect:**
```bash
docker inspect atlatus --format '{{json .HostConfig.LogConfig}}'
sudo journalctl --disk-usage
```

The docker-compose file sets `max-size: 10m` and `max-file: 5` per
container, so any single container's logs are capped at 50 MB.
journald's own retention is governed by `/etc/systemd/journald.conf`
(default keeps until disk pressure).

---

## How to keep this current

When you encounter a new periodic chore, add a section here with the
cadence, the symptom, the procedure, and what success looks like.
Future-you will thank present-you.
