# Disaster recovery drill

**Frequency:** Quarterly (every ~90 days).

**Purpose:** Verify that runbooks, backups, and scripts actually work before a real incident forces you to find out.

---

## Drill procedure

### Scope options (choose one per quarter)

| Level | Scope | Time estimate |
|---|---|---|
| A — Minimal | Test backup integrity + healthcheck only | 15 minutes |
| B — Partial | Restore volume to a test host or throwaway volume | 45 minutes |
| C — Full | Complete fresh VPS rebuild from zero | 2–3 hours |

### Level A — Minimal drill

```bash
# Verify latest backup is readable:
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
BACKUP=$(ls -t /var/backups/hermes/*.tar.age | head -1)
age -d -i "$SOPS_AGE_KEY_FILE" "$BACKUP" | tar -tzf - | head -20

# Run healthcheck:
bash scripts/healthcheck.sh

# Run repo validation:
bash scripts/validate-repo.sh all
```

### Level B — Partial restore drill

Create a separate test volume and restore the backup into it. Do not affect production.

```bash
docker volume create hermes_data_drill_$(date +%s)
# ... restore into the drill volume, verify file counts match ...
docker volume rm hermes_data_drill_*
```

### Level C — Full rebuild drill

Follow `runbooks/full-redeploy-fresh-vps.md` on a scratch VPS (destroy after drill).

---

## Drill log

| Date | Level | Duration | Issues found | Actions taken | Next drill |
|---|---|---|---|---|---|
| YYYY-MM-DD | A/B/C | N min | (none/list) | (none/list) | YYYY-MM-DD |

---

## What to look for

- Backup decrypt fails → check age key, re-examine backup script
- Runbook step fails → update the runbook immediately
- Inventory mismatch → update `inventory/` files
- Scripts fail → fix scripts, re-run drill

Findings must be fixed before the drill is marked complete.
