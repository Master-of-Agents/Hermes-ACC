# Quarterly access review

Run this review every 90 days. Log the result with date and outcome.

## Checklist

### SSH access
- [ ] List keys in `/home/hermesctl/.ssh/authorized_keys` on each VPS.
- [ ] Confirm every key belongs to an active operator.
- [ ] Remove any keys from departed operators or decommissioned workstations.
- [ ] Verify key fingerprints match `vps/ssh-access-model.md`.

### GitHub deploy keys
- [ ] Review GitHub → org → each repo → Settings → Deploy keys.
- [ ] Remove any keys not in use or past their rotation date.
- [ ] Confirm key descriptions match the registry.

### API keys / tokens
- [ ] Review `credentials/credential-registry.yaml` for any credential past its `rotation_frequency_days`.
- [ ] Check provider dashboards for unused or stale keys.
- [ ] Confirm all `last_rotated` dates are accurate.

### Agent permissions
- [ ] Review each active agent manifest in `agents/`.
- [ ] Confirm `allowed_operations` and `forbidden_operations` are still appropriate.
- [ ] Check for any agents granted excess permissions.

### VPS access
- [ ] Verify only `hermesctl` has shell access; root SSH is disabled.
- [ ] Check `/etc/sudoers.d/` for unexpected entries.
- [ ] Review UFW rules against `inventory/ports.yaml`.

## Review log

| Date | Reviewer | Findings | Actions taken |
|---|---|---|---|
| YYYY-MM-DD | primary-admin | (none / list issues) | (none / list actions) |
