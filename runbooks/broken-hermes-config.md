# Runbook: Broken Hermes config

**Purpose:** Recover from a Hermes configuration error that causes the agent to fail on startup or behave incorrectly.

**Preconditions:**
- SSH access to VPS as `hermesctl`
- Age key available

---

## Symptoms

- Container starts then immediately exits
- `docker logs` shows config parse error, missing key, or invalid value
- Agent starts but behaves incorrectly (wrong model, wrong channel, etc.)

---

## Steps

### 1. Diagnose

```bash
docker logs --tail=100 hermes-agent-m5gt-hermes-agent-1
```

Look for config parse errors or missing environment variables.

### 2. Option A — Revert a git-tracked config change

If the config was changed via a commit:

```bash
cd ~/Hermes-ACC
git log --oneline -10
git revert <bad-commit-hash>   # creates a new revert commit
# or on a branch:
git checkout -b fix/config-revert
git revert <bad-commit-hash>
git push origin fix/config-revert
# merge via PR
```

Then redeploy:
```bash
bash scripts/render-env-from-sops.sh /run/hermes/.env
bash scripts/deploy-hermes.sh
```

### 3. Option B — Edit config directly in the volume

```bash
docker compose -f docker/docker-compose.hermes.yml down

# Edit config:
sudo vi /var/lib/docker/volumes/hermes_data/_data/config.yaml

# Start container:
bash scripts/deploy-hermes.sh
```

### 4. Option C — Reset config to defaults

```bash
docker compose -f docker/docker-compose.hermes.yml down
# Back up current (broken) config:
sudo cp /var/lib/docker/volumes/hermes_data/_data/config.yaml \
         /var/lib/docker/volumes/hermes_data/_data/config.yaml.broken.$(date +%s)
# Remove and let Hermes regenerate defaults:
sudo rm /var/lib/docker/volumes/hermes_data/_data/config.yaml
bash scripts/deploy-hermes.sh
```

---

## Verification

`bash scripts/healthcheck.sh` exits 0.
Telegram `/ping` from home chat gets a response.

## Post-conditions (docs to update)

- If a new config failure mode was found, add a note to this runbook.
- Update `hermes/configuration.md` if the fix reveals undocumented config behavior.

## Rollback

Options A/B/C are all reversible (git revert, manual re-edit, or restore from backup).
