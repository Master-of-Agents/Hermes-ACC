# Docker volumes

Machine-readable authoritative data: `inventory/volumes.yaml`.

---

## hermes_data

| Field | Value |
|---|---|
| Type | Named Docker volume |
| Host path | `/var/lib/docker/volumes/hermes_data/_data` |
| Container mount | `/opt/data` (HERMES_HOME) |
| Backup | Daily via `scripts/backup-hermes.sh` |
| Encrypted | Yes (age) |

### Contents

| Path in volume | Purpose | Sensitive? |
|---|---|---|
| `config.yaml` | Hermes agent configuration | Yes — runtime config |
| `auth.json` | Telegram/OAuth token stores | Yes — credentials |
| `sessions/` | Conversation session state | Yes |
| `memory/` | Agent long-term memory | Potentially |
| `skills/` | Loaded skill packs | No |
| `logs/` | Agent operation logs | Low |

### Backup procedure

See `scripts/backup-hermes.sh` and `runbooks/restore-from-backup.md`.
Backups are encrypted with age before being written to `/var/backups/hermes/`.

### Restore procedure

1. `docker compose down`
2. Rename current volume to quarantine: `docker volume create hermes_data_quarantine_$(date +%s)` then copy
3. `docker run --rm -v hermes_data:/data alpine sh -c "rm -rf /data/*"`
4. `bash scripts/restore-hermes.sh <backup.tar.age>`
5. `docker compose up -d`
6. Run `scripts/healthcheck.sh`
7. Quarantined volume can be deleted after 7 days if all is well.

### Guidelines

- Never mount `hermes_data` read-write from two containers simultaneously.
- `auth.json` and OAuth stores inside the volume are sensitive — they are covered by the backup encryption.
- Do not bind-mount the host path directly in production; use the named volume.
