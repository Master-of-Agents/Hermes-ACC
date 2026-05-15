# Naming conventions

Single source of truth for how things in the Hermes stack are named.
When a script, runbook, or config needs to name a resource, it cites
this document instead of reinventing a convention.

---

## Three layers of identity

Don't conflate these — they're separate concerns:

| Layer | Identity | Scope | Example |
|---|---|---|---|
| **System** | "Hermes" | The whole stack — controlling repo, ops user, GitHub org context | `Hermes-ACC`, `hermesctl`, `Master-of-Agents` |
| **Agent** | `<agent-name>` | One agent | `atlatus`, `correspondence`, `calendar` |
| **Container-internal** | `hermes` (UID 10000) | Process user inside every Hermes container | (set by Hostinger image, immutable) |

The system name is shared. The agent name varies. The container-internal
user is the same for every agent because the container image is the same.

---

## What stays "Hermes" (system-level — never renamed per agent)

| Name | Why |
|---|---|
| `Hermes-ACC` (repo) | Controlling/admin repo for the whole stack. One per ecosystem. |
| `hermesctl` (Linux user on VPS) | VPS operator account. Owns sudo, docker group, secrets. One per VPS regardless of agent count. |
| `Master-of-Agents` (GitHub org) | Different vocabulary layer; predates and outlives Hermes. |
| `hermes` (UID 10000 inside containers) | Set by the Hostinger image — not under our control. |

---

## What is named per agent

Use the agent's short name (lowercase, no spaces, ASCII only). The
agent's name is the **only** variable in the pattern.

| Resource | Pattern | Example (`atlatus`) |
|---|---|---|
| Container | `<name>` | `atlatus` |
| Docker volume | `data-<name>` | `data-atlatus` |
| Sops file | `secrets/<name>.env.enc.yaml` | `secrets/atlatus.env.enc.yaml` |
| State repo (GitHub) | `Master-of-Agents/state-<name>` | `Master-of-Agents/state-atlatus` |
| Gateway systemd unit | `gateway-<name>.service` | `gateway-atlatus.service` |
| Backup systemd unit | `backup-<name>.service` + `.timer` | `backup-atlatus.service` |
| Host port (host side of container port mapping) | allocated by `agents/registry.yaml` | 32768 (first agent), 32769, … |
| Operator SSH key on workstation (per VPS, not per agent) | `~/.ssh/id_ed25519_hermes_<vps-tag>` | unchanged from `ssh-access-model.md` |

The Hostinger container's internal port (`4860`) is the same for every
agent because it's set inside the image. Only the **host** side of the
port mapping is allocated per-agent.

---

## Convention for the agent name itself

- Lowercase, ASCII letters and digits, hyphens allowed.
- Stable for the agent's lifetime — renaming an agent is treated as
  creating a new one and decommissioning the old one (avoids cross-cutting
  rename in containers, volumes, repos, sops, services, …).
- Short enough to type comfortably in commands; ideally one word.

Good: `atlatus`, `correspondence`, `calendar`, `coder`.
Avoid: `Atlatus` (case), `email_assistant` (underscore breaks docker
volume naming on some hosts), `the-correspondence-agent` (too long).

---

## When you add a new agent

The new-agent procedure ("phase B onward") creates each of these
resources once:

1. Choose `<name>`.
2. Append a row to `agents/registry.yaml` (the source of truth — allocates
   host port, records VPS, links state repo, etc.).
3. Create `secrets/<name>.env.enc.yaml` and add per-agent secrets
   (`TELEGRAM_BOT_TOKEN`, `XAI_API_KEY` if separate, etc.).
4. Create `Master-of-Agents/state-<name>` as a private GitHub repo with
   a README.
5. Generate a backup deploy key, register on the state repo with write
   access, run `install-backup-timer.sh AGENT_NAME=<name>`.
6. Bring up the container (`docker compose up -d` with the parameterized
   compose file).
7. Run `hermes setup` wizard once.
8. Install `gateway-<name>.service`.
9. Verify, reboot test, mark "active" in the registry.

This document drives every step. If a script doesn't read from
`agents/registry.yaml`, it's a bug.

---

## Pre-multi-agent migration debt

The current Atlatus production deployment uses a few legacy names from
before the convention was finalized:

| Current name | Target name |
|---|---|
| `hermes-agent` (container) | `atlatus` |
| `hermes_data` (volume) | `data-atlatus` |
| `hermes.env.enc.yaml` (sops) | `atlatus.env.enc.yaml` |
| `hermes-state-atlatus` (state repo) | `state-atlatus` |
| `hermes-gateway.service` (systemd) | `gateway-atlatus.service` |
| `hermes-backup-atlatus.*` (systemd) | `backup-atlatus.*` |

These will be migrated in a focused session before agent #2 lands. See
the migration plan referenced from the runbooks for the procedure (data
copy, downtime estimate ~5 min).
