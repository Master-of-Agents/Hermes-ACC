# Post-bootstrap agent setup

This runbook covers everything between `bootstrap-vps.sh` finishing and
the Telegram bot being live as a managed service.

**When to run:** after a fresh VPS bootstrap, after replacing the
`data-atlatus` Docker volume, or after a from-scratch disaster recovery.

**When NOT to run:** during day-to-day operation. The systemd service
handles container restart and gateway recovery automatically.

---

## Prerequisites

- `scripts/bootstrap-vps.sh` has completed successfully
- The `atlatus` container is running (verify with `docker ps`)
- You can reach the VPS over SSH as `hermesctl`

## Step 1 — Run the Hermes setup wizard

The agent image ships with a first-run wizard that writes configuration
to the `data-atlatus` volume. It is interactive and runs via the ttyd web
terminal — you cannot script it.

1. Open `http://<VPS_IP>:32768` in a browser
2. When prompted for HTTP Basic Auth, leave both fields **empty** and
   click Sign In (the ttyd is configured with `-c :`)
3. The wizard greets you with `How would you like to set up Hermes?`
4. Follow `hermes/wizard-choices.md` for every prompt
5. At the end, when asked `Launch hermes chat now? [Y/n]:` answer **`n`**

The wizard saves `/opt/data/config.yaml` and `/opt/data/.env` to the
`data-atlatus` volume.

## Step 2 — Install the gateway systemd service

This wires up boot-time env rendering, container ensure, and gateway
start as a single managed service:

```bash
sudo bash ~/Hermes-ACC/scripts/install-gateway-service.sh
```

The service is enabled (auto-starts on boot) and started immediately.
It performs four pre-start steps on every start:

1. Renders `/run/atlatus/.env` from sops
2. Brings up the container via `docker compose up -d`
3. Waits for `Running` state
4. Runs `hermes gateway run --replace` as the `hermes` user

## Step 3 — Verify

```bash
sudo systemctl status gateway-atlatus
bash ~/Hermes-ACC/scripts/healthcheck.sh
```

Expected:
- `systemctl status` shows **active (running)**
- All four healthcheck items pass

Then send a Telegram message to the bot. The bot should reply.

## Step 4 — Reboot test (optional but recommended)

```bash
sudo reboot
```

Wait ~60 seconds, then send a Telegram message. The bot should respond
without any manual intervention. This confirms the systemd boot chain
works end to end.

## Step 5 — Set up hourly state backup (recommended for any agent you intend to keep)

Without this, the agent's identity (`SOUL.md`, skills, memory, scheduled
crons, state.db) lives only in the VPS's Docker volume. If the volume is
lost or corrupted, the agent has to be rebuilt from scratch via the wizard.

The backup pipeline pushes a snapshot to a per-agent GitHub repo every
hour. Restore is a single `docker cp` per item (see
`runbooks/new-vps-from-zero.md` Phase 5.5).

### 5a. Pick the agent name

Used in repo and key names. Lowercase, no spaces. For the founding
agent this is `atlatus`.

```bash
AGENT_NAME=atlatus   # change for each agent
GITHUB_ORG=Master-of-Agents
```

### 5b. Create the state repo on GitHub

1. Go to https://github.com/organizations/${GITHUB_ORG}/repositories/new
2. Repository name: `state-${AGENT_NAME}`
3. **Private**
4. ✅ Initialize with a README (gives the repo a default branch)
5. Create

### 5c. Generate the write-enabled deploy key on the VPS

```bash
ssh-keygen -t ed25519 \
  -f ~/.ssh/id_ed25519_state_${AGENT_NAME} \
  -N "" \
  -C "${AGENT_NAME}-state-backup-$(hostname -s)"
chmod 600 ~/.ssh/id_ed25519_state_${AGENT_NAME}
cat ~/.ssh/id_ed25519_state_${AGENT_NAME}.pub
ssh-keygen -lf ~/.ssh/id_ed25519_state_${AGENT_NAME}.pub
```

Copy the public key (the `ssh-ed25519 …` line). Record the fingerprint
in `credentials/credential-registry.yaml` (`GITHUB_STATE_BACKUP_KEY_*`).

### 5d. Register the public key on the new repo

1. On the new repo: **Settings → Deploy keys → Add deploy key**
2. Title: `<hostname> backup writer`
3. Key: paste the public key
4. ✅ **Check "Allow write access"** — required to push backups
5. Add key

### 5e. Install the timer

```bash
AGENT_NAME=${AGENT_NAME} GITHUB_ORG=${GITHUB_ORG} \
  bash ~/Hermes-ACC/scripts/install-backup-timer.sh
```

This:
- Adds an SSH host alias for the backup key in `~/.ssh/config`
- Clones the state repo to `~/state-${AGENT_NAME}`
- Installs `backup-${AGENT_NAME}.service` + `.timer`
- Enables and starts the timer (hourly, persistent, 120s jitter)

### 5f. Trigger the first backup and verify

```bash
sudo systemctl start backup-${AGENT_NAME}.service
sudo journalctl -u backup-${AGENT_NAME}.service -n 20 --no-pager
```

Expected: "Backup committed and pushed: <timestamp>".

Open the GitHub repo and confirm `SOUL.md`, `skills/`, `cron/`,
`state.db`, and `config.yaml` are present, and that `api_key:` lines in
`config.yaml` are `REDACTED`.

### 5g. Confirm the timer is scheduled

```bash
systemctl list-timers backup-${AGENT_NAME}.timer --no-pager
```

Next firing should be within the next hour.

## Troubleshooting

### Wizard auto-detects wrong values

Edit `/opt/data/config.yaml` directly inside the container:

```bash
docker exec -u hermes -it atlatus nano /opt/data/config.yaml
```

Or re-run a specific section of the wizard:

```bash
docker exec -u hermes -it atlatus hermes setup model
docker exec -u hermes -it atlatus hermes setup gateway
```

### Gateway service fails with "already running"

Another gateway instance is alive inside the container (from a manual
start or stale state). The service uses `--replace` to take over
automatically — if it still fails, kill the inner process:

```bash
docker exec atlatus pkill -f "hermes gateway"
sudo systemctl restart gateway-atlatus
```

### Bot doesn't respond after a reboot

```bash
sudo journalctl -u gateway-atlatus -n 50 --no-pager
```

Common causes:
- Container failed to start (check `docker ps`)
- sops decrypt failed (check `SOPS_AGE_KEY_FILE` exists)
- Hermes config in the volume is corrupted (last resort: remove volume,
  re-run wizard)
