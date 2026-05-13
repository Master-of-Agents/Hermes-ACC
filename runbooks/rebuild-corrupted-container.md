# Runbook: Rebuild corrupted container

**Purpose:** Recover the Hermes agent container when it is in a crash loop, healthcheck failure, or otherwise broken state.

**Preconditions:**
- SSH access to VPS as `hermesctl`
- Age key available at `~/.config/sops/age/keys.txt`
- `~/Hermes-ACC` cloned and current

---

## Symptoms

- Container restarting in a loop: `docker ps` shows status "Restarting"
- `bash scripts/healthcheck.sh` fails
- Agent unresponsive in Telegram
- `docker logs` shows panic, config error, or missing env vars

---

## Steps

### 1. Gather diagnostics (before touching anything)

```bash
docker ps -a
docker logs --tail=50 hermes-agent-m5gt-hermes-agent-1
bash scripts/healthcheck.sh || true
```

### 2. Stop the container (do NOT delete the volume)

```bash
docker compose -f docker/docker-compose.hermes.yml down
# Verify volume still exists:
docker volume ls | grep hermes_data
```

### 3. Try a simple pull-and-restart

```bash
docker compose -f docker/docker-compose.hermes.yml pull
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
bash scripts/render-env-from-sops.sh /run/hermes/.env
bash scripts/deploy-hermes.sh
```

Check: `bash scripts/healthcheck.sh`

### 4. If still broken — check for config issues

```bash
# Inspect volume contents:
docker run --rm -v hermes_data:/data:ro alpine ls -la /data
docker run --rm -v hermes_data:/data:ro alpine cat /data/config.yaml
```

If config is corrupt, see `runbooks/broken-hermes-config.md`.

### 5. If env/secrets are broken

```bash
# Verify sops can decrypt:
sops -d secrets/hermes.env.enc.yaml
# Re-render:
bash scripts/render-env-from-sops.sh /run/hermes/.env
bash scripts/deploy-hermes.sh
```

### 6. If image is broken — pin to a previous version

```bash
# Set a known-good image in environment or inventory:
HERMES_IMAGE=ghcr.io/hostinger/hvps-hermes-agent:<previous-tag> \
  docker compose -f docker/docker-compose.hermes.yml up -d
```

Update `inventory/containers.yaml → image_previous` with the broken tag for reference.

### 7. If data volume is corrupt — restore from backup

Follow `runbooks/restore-from-backup.md`.

---

## Verification

`bash scripts/healthcheck.sh` exits 0.
Telegram `/ping` from home chat gets a response.

## Post-conditions (docs to update)

- `inventory/containers.yaml` — update `image_previous` if image was changed
- Add notes to `docs/design-decisions.md` if a new failure mode was encountered

## Rollback

The volume is preserved throughout. If the new image is also broken, pin back to the previous tag.
If the volume is corrupt, restore from `runbooks/restore-from-backup.md`.
