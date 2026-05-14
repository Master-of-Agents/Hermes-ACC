# Post-bootstrap agent setup

This runbook covers everything between `bootstrap-vps.sh` finishing and
the Telegram bot being live as a managed service.

**When to run:** after a fresh VPS bootstrap, after replacing the
`hermes_data` Docker volume, or after a from-scratch disaster recovery.

**When NOT to run:** during day-to-day operation. The systemd service
handles container restart and gateway recovery automatically.

---

## Prerequisites

- `scripts/bootstrap-vps.sh` has completed successfully
- The `hermes-agent` container is running (verify with `docker ps`)
- You can reach the VPS over SSH as `hermesctl`

## Step 1 — Run the Hermes setup wizard

The agent image ships with a first-run wizard that writes configuration
to the `hermes_data` volume. It is interactive and runs via the ttyd web
terminal — you cannot script it.

1. Open `http://<VPS_IP>:32768` in a browser
2. When prompted for HTTP Basic Auth, leave both fields **empty** and
   click Sign In (the ttyd is configured with `-c :`)
3. The wizard greets you with `How would you like to set up Hermes?`
4. Follow `hermes/wizard-choices.md` for every prompt
5. At the end, when asked `Launch hermes chat now? [Y/n]:` answer **`n`**

The wizard saves `/opt/data/config.yaml` and `/opt/data/.env` to the
`hermes_data` volume.

## Step 2 — Install the gateway systemd service

This wires up boot-time env rendering, container ensure, and gateway
start as a single managed service:

```bash
sudo bash ~/Hermes-ACC/scripts/install-gateway-service.sh
```

The service is enabled (auto-starts on boot) and started immediately.
It performs four pre-start steps on every start:

1. Renders `/run/hermes/.env` from sops
2. Brings up the container via `docker compose up -d`
3. Waits for `Running` state
4. Runs `hermes gateway run --replace` as the `hermes` user

## Step 3 — Verify

```bash
sudo systemctl status hermes-gateway
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

## Troubleshooting

### Wizard auto-detects wrong values

Edit `/opt/data/config.yaml` directly inside the container:

```bash
docker exec -u hermes -it hermes-agent nano /opt/data/config.yaml
```

Or re-run a specific section of the wizard:

```bash
docker exec -u hermes -it hermes-agent hermes setup model
docker exec -u hermes -it hermes-agent hermes setup gateway
```

### Gateway service fails with "already running"

Another gateway instance is alive inside the container (from a manual
start or stale state). The service uses `--replace` to take over
automatically — if it still fails, kill the inner process:

```bash
docker exec hermes-agent pkill -f "hermes gateway"
sudo systemctl restart hermes-gateway
```

### Bot doesn't respond after a reboot

```bash
sudo journalctl -u hermes-gateway -n 50 --no-pager
```

Common causes:
- Container failed to start (check `docker ps`)
- sops decrypt failed (check `SOPS_AGE_KEY_FILE` exists)
- Hermes config in the volume is corrupted (last resort: remove volume,
  re-run wizard)
