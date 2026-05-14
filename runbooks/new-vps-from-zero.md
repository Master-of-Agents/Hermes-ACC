# Runbook: New VPS from zero

**Purpose:** Provision and fully configure a brand-new VPS from first
root login to a running, managed Hermes agent. Use this verbatim for
disaster recovery or any time the existing VPS is unrecoverable.

**Time estimate:** 45–75 minutes including a careful wizard pass.

---

## Pre-flight — retrieve from Bitwarden

Before touching the VPS, line up these items so you don't break flow:

| Bitwarden entry | What you'll use it for |
|---|---|
| `Hostinger` | Login to the Hostinger control panel |
| `Hostinger VPS` (root) | First SSH session as root |
| `Hermes age private key (srv...)` | Decrypt sops secrets on the new VPS |
| `Hermes age RECOVERY key` | Fallback if primary key is corrupted |
| `GitHub` (Master-of-Agents) | Add the deploy key to the repo |
| `Telegram` (@BotFather) | Recreate the bot only if the old token is gone |
| `x.AI (Grok API)` | If you need to re-enter the API key in the wizard. **If the wizard fails with `HTTP 400` errors after model selection, generate a fresh xAI API key in the xAI console and use that instead — keys can become tier-restricted or lose access to specific model features over time.** |

Also have ready:
- Operator workstation SSH key (`~/.ssh/id_ed25519_hermes_vps`) — if you
  switched workstations, generate a new one
- GitHub deploy key (`~/.ssh/id_ed25519_hermes_acc`) — same: generate
  new if lost; the old one is rotated regardless

---

## Phase 1 — Provision the VPS (Hostinger panel)

1. Order a fresh VPS in the Hostinger panel (Ubuntu 24.04 LTS).
2. Note the new public IP and hostname.
3. Upload the operator workstation public key in Hostinger → SSH keys
   so root SSH works from the start.

## Phase 2 — Break-glass (root → hermesctl)

Follow `vps/bootstrap-notes.md` exactly. Summary:

1. SSH as root.
2. Create `hermesctl` user with passwordless sudo.
3. Install operator's SSH public key into `~hermesctl/.ssh/authorized_keys`.
4. Copy the GitHub deploy key (`id_ed25519_hermes_acc`) onto the VPS at
   `~hermesctl/.ssh/id_ed25519_hermes_acc` (chmod 600). Configure
   `~hermesctl/.ssh/config` for `github.com`.
5. **Register the deploy key in GitHub:** repo Settings → Deploy keys →
   Add new → paste the `.pub` content → check "Allow write access" only
   if needed (read-only is correct for Hermes-ACC).
6. Harden SSH (disable root login, disable password auth, reload sshd).
7. Verify `hermesctl` SSH login works from a second terminal **before**
   closing the root session.

## Phase 3 — Place the age key

The age private key must be on the VPS before bootstrap can render secrets.

On the VPS as `hermesctl`:

```bash
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops/age
nano ~/.config/sops/age/keys.txt
# Paste the full content of the "Hermes age private key" entry from Bitwarden
# (includes the # created comment, the # public key comment, and the AGE-SECRET-KEY-... line)
chmod 600 ~/.config/sops/age/keys.txt
```

## Phase 4 — Clone repo and run bootstrap

```bash
git clone git@github.com:Master-of-Agents/Hermes-ACC.git ~/Hermes-ACC
cd ~/Hermes-ACC

# Dry run first — review the actions
DRY_RUN=1 bash scripts/bootstrap-vps.sh

# Live run
bash scripts/bootstrap-vps.sh
```

The script runs all 8 steps. At step 8 it will tell you the gateway
service is **not yet installed** because the wizard hasn't run — that
is expected on a fresh VPS.

## Phase 5 — Hermes setup wizard

Open `http://<new_VPS_IP>:32768` in a browser. The ttyd web terminal
launches `hermes setup`.

Follow `hermes/wizard-choices.md` for every prompt. The xAI API key
will be auto-detected from `/run/hermes/.env` (rendered from sops in
step 6 of bootstrap).

At the end, when prompted `Launch hermes chat now? [Y/n]:` answer **`n`**.

## Phase 6 — Install the gateway systemd service

Re-run the bootstrap (step 8 will now detect the wizard config and
install the service):

```bash
bash ~/Hermes-ACC/scripts/bootstrap-vps.sh
```

Or run the service installer directly:

```bash
sudo bash ~/Hermes-ACC/scripts/install-gateway-service.sh
```

## Phase 7 — Verify

```bash
sudo systemctl status hermes-gateway
bash ~/Hermes-ACC/scripts/healthcheck.sh
sudo ufw status verbose
```

Expected:
- Gateway service: **active (running)**
- Healthcheck: **4 passed, 0 failed**
- UFW: SSH (22) and Hermes (32768) allowed

Send a Telegram message. The bot should respond.

## Phase 8 — Reboot test

```bash
sudo reboot
```

Wait 60 seconds, send another Telegram message. Bot must respond
without intervention. This proves the systemd boot chain works.

## Phase 9 — Update inventory

Commit the new VPS facts to the repo:

- `inventory/servers.yaml` — IP, hostname, OS version (`Ubuntu 24.04.x`)
- `vps/hostinger-<new_hostname>.md` — host-specific notes
- `vps/ssh-access-model.md` — new operator SSH key fingerprint if it
  changed
- `credentials/credential-registry.yaml` — update `last_rotated` for
  any keys regenerated during this drill

---

## Common pitfalls (discovered during the 2026-05-14 drill)

### `HTTP 400` from xAI after wizard
The LLM provider key may have lost access to its expected feature set
(reasoning models in particular). **Fix:** generate a fresh xAI API key
in the xAI console, re-run `hermes setup model`, paste the new key.
Update sops (`XAI_API_KEY`) once recovery is confirmed.

### Container starts but `/run/hermes/.env` was overwritten
Every restart of `hermes-gateway.service` re-renders `/run/hermes/.env`
from sops. Any manual edits to that file are lost. If you need a
different secret value (e.g. a drill bot token), update sops itself.

### `PermissionError: /opt/data/logs/gateway.log` on first start
If `hermes setup` runs the gateway interactively before the systemd
service is installed, it may create the log file as root. Fix:
```bash
docker exec hermes-agent chown hermes:hermes /opt/data/logs/gateway.log
sudo systemctl restart hermes-gateway
```

### `permission denied while trying to connect to the docker API`
After bootstrap, hermesctl wasn't in the docker group at the time the
session started. Fix:
```bash
sudo usermod -aG docker hermesctl
exit  # log out and back in
```
Then re-run bootstrap-vps.sh — it's idempotent.

### Drill-specific: production and drill on the same Telegram bot token
The sops file ships one production `TELEGRAM_BOT_TOKEN`. A drill VPS
that uses the same sops file will compete with production for Telegram
updates. Create a separate drill bot via `@BotFather` and either:
- Override `TELEGRAM_BOT_TOKEN` in `/opt/data/.env` via the wizard
  (drill agent reads from `/opt/data/.env` after env_file is loaded), or
- Maintain a separate sops file with the drill token

## Rollback

This is a fresh setup. If something breaks irrecoverably, re-provision
the VPS and start over from Phase 1. Nothing on the old VPS depends on
the new one until you cut over.

## Cutover (if replacing a live VPS)

Only after Phase 8 passes on the new VPS:

1. Update DNS or Telegram webhook (if used) to point at the new IP.
2. Stop the old VPS's `hermes-gateway.service` to prevent dual
   processing of Telegram updates.
3. Run a final Telegram test against the new VPS.
4. Decommission the old VPS in the Hostinger panel.
