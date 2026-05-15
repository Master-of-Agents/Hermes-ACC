# Runbook: Add a new agent

**Purpose:** Provision a new agent (specialist or orchestrator) onto
an existing VPS, following the per-agent naming convention.

**Time estimate:** 30–45 minutes for first time; ~20 minutes once the
pattern is muscle memory.

**Preconditions:**
- An existing VPS already bootstrapped via `runbooks/new-vps-from-zero.md`
- That VPS has at least one agent (e.g. Atlatus) running cleanly
- Operator has GitHub access to the `Master-of-Agents` org
- Conventions in `docs/naming-conventions.md` understood

---

## Step 0 — Choose the agent name and pick a port

The agent name follows `docs/naming-conventions.md`: lowercase ASCII,
short, stable. Examples: `correspondence`, `calendar`, `coder`.

Open `agents/registry.yaml`, find the next free host port (port 32768
is Atlatus; specialists go 32769, 32770, …).

For the rest of this runbook, replace placeholders:
- `<name>` — your chosen agent name
- `<port>` — your chosen host port (e.g. `32769`)

## Step 1 — Add the agent to `agents/registry.yaml`

In your Hermes-ACC clone, add a new entry to `agents/registry.yaml`.
Use the commented-out template at the bottom of that file as a starting
point. Mark `status: planned` for now.

Commit and push:
```bash
git add agents/registry.yaml
git commit -m "registry: add <name> (planned)"
git push
```

## Step 2 — Create the per-agent sops file

```bash
cp templates/.env.hermes.example secrets/<name>.env.enc.yaml.plain  # or similar
# Fill in placeholder values for TELEGRAM_BOT_TOKEN (only if specialist
# needs its own bot — most don't), XAI_API_KEY (or shared from elsewhere),
# any other secrets specific to this agent's role.
```

Then encrypt with sops (the .sops.yaml `path_regex` already matches
`secrets/.*\.enc\.yaml`):
```bash
sops -e secrets/<name>.env.enc.yaml.plain > secrets/<name>.env.enc.yaml
rm secrets/<name>.env.enc.yaml.plain  # never commit plaintext
git add secrets/<name>.env.enc.yaml
git commit -m "secrets: add encrypted env for <name>"
git push
```

## Step 3 — Create the docker-compose file for the agent

```bash
cp docker/docker-compose.atlatus.yml docker/docker-compose.<name>.yml
```

Edit `docker/docker-compose.<name>.yml`:
- Change service name and `container_name` from `atlatus` to `<name>`.
- Change volume name from `data-atlatus` to `data-<name>` (both in the
  `volumes:` block on the service and in the top-level `volumes:` map).
- Change env-var prefixes from `ATLATUS_*` to `<NAME>_*` (uppercase).
- Update the `env_file` path to `/run/<name>/.env`.
- If this is a specialist (no Telegram of its own), consider removing
  the host port mapping entirely — the agent only needs to be reachable
  on the docker network. Specialists exposed via MCP keep an internal
  port but no host mapping.
- If this is a specialist accepting MCP from atlatus, give it a port
  binding only to localhost or remove the host mapping entirely.

Commit and push.

## Step 4 — Create the state repo on GitHub

In a browser:
1. New repo at https://github.com/organizations/Master-of-Agents/repositories/new
2. Name: `state-<name>`
3. Private
4. Initialize with README

## Step 5 — Generate the backup deploy key on the VPS

```bash
# On the VPS as hermesctl
ssh-keygen -t ed25519 \
  -f ~/.ssh/id_ed25519_state_<name> \
  -N "" \
  -C "<name>-state-backup-$(hostname -s)"
chmod 600 ~/.ssh/id_ed25519_state_<name>
cat ~/.ssh/id_ed25519_state_<name>.pub
ssh-keygen -lf ~/.ssh/id_ed25519_state_<name>.pub  # capture the fingerprint
```

Register the public key on `state-<name>` → Settings → Deploy keys →
Add. **Check "Allow write access".**

## Step 6 — Update the credential registry

Append a new entry to `credentials/credential-registry.yaml` analogous to
`GITHUB_STATE_BACKUP_KEY_ATLATUS`, with:
- `name: GITHUB_STATE_BACKUP_KEY_<NAME>` (uppercase)
- `purpose: "Write-enabled deploy key — pushes hourly agent-state snapshots to Master-of-Agents/state-<name>"`
- The fingerprint you captured in Step 5
- Updated paths

Commit and push.

## Step 7 — Pull on the VPS, render env, deploy

```bash
# On the VPS as hermesctl
cd ~/Hermes-ACC
git pull

SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
  bash scripts/render-env-from-sops.sh <name> /run/<name>/.env

bash scripts/deploy-agent.sh <name>

docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Confirm the `<name>` container is `Up` and healthy.

## Step 8 — Run the Hermes setup wizard for the new agent

Open `http://<VPS_IP>:<port>` in a browser. Walk through
`hermes/wizard-choices.md`, adapted for the new agent's role.

For specialists:
- Skip the Telegram step (specialists don't talk to users directly), or
  use a different bot if you do want a Telegram surface for this agent.
- The model and provider choices follow the same template as Atlatus.

At the end, answer `n` to "Launch hermes chat now?"

## Step 9 — Install the gateway and backup systemd services

```bash
# Gateway service (handles env render + container ensure + gateway start)
sudo AGENT_NAME=<name> bash ~/Hermes-ACC/scripts/install-gateway-service.sh

# Backup pipeline
AGENT_NAME=<name> GITHUB_ORG=Master-of-Agents \
  bash ~/Hermes-ACC/scripts/install-backup-timer.sh

# Trigger first backup to verify pipeline end-to-end
sudo systemctl start backup-<name>.service
sudo journalctl -u backup-<name>.service -n 20 --no-pager | tail -10
```

The backup should commit and push to `Master-of-Agents/state-<name>`.

## Step 10 — Verify

```bash
systemctl is-active gateway-<name> backup-<name>.timer
bash scripts/healthcheck.sh   # HERMES_CONTAINER_NAME=<name> bash scripts/healthcheck.sh for non-default
docker ps --format "table {{.Names}}\t{{.Status}}"
```

All three should show healthy / active.

If the agent has a Telegram interface, send it a test message and
confirm it responds. If it's a specialist with an MCP endpoint, test
the MCP call from atlatus (or whichever agent will delegate to it).

## Step 11 — Mark the agent active in the registry

Edit `agents/registry.yaml`, change `status: planned` to `status: active`,
fill in any fields that were unknown at Step 1 (fingerprints, final
config decisions).

```bash
git add agents/registry.yaml credentials/credential-registry.yaml
git commit -m "agents: <name> is live"
git push
```

## Step 12 — Reboot test (recommended)

```bash
sudo reboot
```

Wait 60 sec, reconnect, verify both agents (existing + new) come back
without manual intervention. This proves the systemd boot chain still
works after introducing the new agent.

---

## Verification

- `systemctl is-active gateway-<name> backup-<name>.timer` returns `active` for both
- `docker ps` shows the new container `Up` and healthy
- An hourly backup commits to `Master-of-Agents/state-<name>`
- The new agent is reachable on its designated interface (Telegram for
  orchestrators, MCP / direct call for specialists)
- After a reboot, no manual intervention is needed

## Post-conditions (docs already updated above)

- `agents/registry.yaml` — agent entry, `status: active`
- `credentials/credential-registry.yaml` — `GITHUB_STATE_BACKUP_KEY_<NAME>` entry
- `secrets/<name>.env.enc.yaml` — committed
- `docker/docker-compose.<name>.yml` — committed

## Rollback

If the agent fails to come up cleanly:

1. `sudo systemctl disable --now gateway-<name>.service backup-<name>.timer`
2. `docker compose -f docker/docker-compose.<name>.yml down -v` (the `-v` removes the volume too — only do this for a never-completed agent that has nothing worth preserving)
3. Delete the state repo on GitHub (if no useful backups were committed)
4. Set `status: planned` in `agents/registry.yaml` and remove the
   credential registry entry
5. Investigate, fix, restart from Step 7

If the agent has been live and accumulated state, treat this as a
disaster recovery — see `runbooks/new-vps-from-zero.md` Phase 6.5
(restore from backup) instead.
