# Runbook: New VPS from zero

**Purpose:** Provision and fully configure a brand-new Hostinger VPS from the first root login to a running Hermes agent.

**Preconditions:**
- New VPS provisioned in Hostinger panel
- Operator has: SSH key pair, age private key, GitHub deploy key, all sops-encrypted credentials current
- Operator has access to the Hermes-ACC repo

---

## Steps

### Phase 1 — Manual break-glass (operator, as root)

Follow `vps/bootstrap-notes.md` in full:

1. SSH as root using Hostinger console or welcome credentials.
2. Create `hermesctl` user with passwordless sudo.
3. Install operator SSH public key into `hermesctl`'s `authorized_keys`.
4. Place GitHub deploy key at `/home/hermesctl/.ssh/id_ed25519_hermes_acc`.
5. Harden SSH: disable root login, disable password auth.
6. Verify `hermesctl` SSH login works from a second terminal before closing root session.

### Phase 2 — Bootstrap (as hermesctl)

```bash
ssh hermesctl@VPS_HOST

# Clone the repo
git clone git@github.com:Master-of-Agents/Hermes-ACC.git ~/Hermes-ACC
cd ~/Hermes-ACC

# Place age private key (from offline backup or workstation)
mkdir -p ~/.config/sops/age
# scp ~/.config/sops/age/keys.txt hermesctl@VPS_HOST:~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Run bootstrap script
DRY_RUN=1 bash scripts/bootstrap-vps.sh   # review first
bash scripts/bootstrap-vps.sh
```

### Phase 3 — Verification

Follow `checks/post-deploy-verification.md`.

---

## Verification

- `bash scripts/healthcheck.sh` exits 0
- Telegram `/ping` from home chat gets a response
- `sudo ufw status` shows only SSH and Hermes port open

## Post-conditions (docs to update)

- `inventory/servers.yaml` — add or update server entry with new IP/hostname
- `vps/hostinger-<hostname>.md` — create host-specific notes file if new host
- `vps/ssh-access-model.md` — add new key fingerprint if applicable

## Rollback

N/A — this is a fresh setup. If it fails, re-provision the VPS and start again.
