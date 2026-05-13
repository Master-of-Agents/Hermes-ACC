# Pre-deploy preflight checklist

Run before every deploy, major config change, or credential rotation.

## Checklist

### Repository state
- [ ] `git status` is clean or changes are intentional
- [ ] `bash scripts/validate-repo.sh all` passes
- [ ] `pre-commit run --all-files` passes (no secret patterns, no YAML errors)
- [ ] All changed YAML has `schema_version: "1.0"`

### Secrets
- [ ] `SOPS_AGE_KEY_FILE` is set and the file exists
- [ ] `sops -d secrets/hermes.env.enc.yaml` succeeds (verify decryption works)
- [ ] `secrets/hermes.env.enc.yaml` does not contain placeholder values

### Container
- [ ] `docker compose config -f docker/docker-compose.hermes.yml` is valid
- [ ] Latest image tag is confirmed in `inventory/containers.yaml`

### VPS (if SSH available)
- [ ] `ssh hermesctl@VPS_HOST` succeeds
- [ ] `docker ps` shows container running (if not a fresh redeploy)
- [ ] `/run/hermes/.env` exists and is 0600

### Backups (for major changes)
- [ ] Latest backup exists in `/var/backups/hermes/` and is recent
- [ ] Backup integrity verified: `age -d | tar -tzf -` succeeds

---

All checks passed? Proceed to deployment.
Any check failed? Resolve before continuing.
