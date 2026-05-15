# Runbook: Restore from backup

**Purpose:** Restore the Hermes `data-atlatus` volume from an encrypted backup archive.

**Preconditions:**
- Age private key available at `SOPS_AGE_KEY_FILE`
- Target backup file accessible on the VPS
- SSH access to VPS as `hermesctl`

---

## Steps

### 1. Identify the backup to restore

```bash
ls -lht /var/backups/hermes/
```

Naming convention: `hermes-<host>-data-atlatus-<YYYYMMDDTHHMMSSZ>.tar.age`

Choose the latest good backup (or the specific point-in-time you need).

### 2. Verify backup integrity before restoring

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
age -d -i "$SOPS_AGE_KEY_FILE" /var/backups/hermes/<backup>.tar.age | tar -tzf - | head -20
```

If this fails: backup is corrupt. Try the previous backup.

### 3. Run the restore script (dry-run first)

```bash
DRY_RUN=1 bash scripts/restore-hermes.sh /var/backups/hermes/<backup>.tar.age
```

Review the dry-run output, then run live:

```bash
bash scripts/restore-hermes.sh /var/backups/hermes/<backup>.tar.age
```

The script will:
- Stop the container
- Quarantine the current volume (NOT delete it)
- Extract the backup into `data-atlatus`
- Start the container
- Run the healthcheck

### 4. Verify

```bash
bash scripts/healthcheck.sh
```

Send `/ping` from the Telegram home chat.

Check that agent memory and config are from the expected point in time.

### 5. Clean up quarantine volume (after 7 days)

```bash
# Only after verifying the restore is working well:
docker volume rm data-atlatus_quarantine_<timestamp>
```

---

## Verification

- Healthcheck passes
- Telegram `/ping` responds
- Agent data matches expected restore point

## Post-conditions (docs to update)

- Add a line to `checks/disaster-recovery-drill.md` if this was a drill
- Note any issues found for future backup/restore improvement

## Rollback

The quarantined volume is the rollback path.

```bash
docker compose -f docker/docker-compose.atlatus.yml down
# Restore from quarantine:
docker run --rm \
  -v data-atlatus_quarantine_<timestamp>:/src:ro \
  -v data-atlatus:/dst \
  alpine sh -c "cp -a /src/. /dst/"
docker compose -f docker/docker-compose.atlatus.yml up -d
```
