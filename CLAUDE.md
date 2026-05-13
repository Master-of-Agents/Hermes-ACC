# CLAUDE.md — Agent contract for Hermes-ACC

Read this file first before taking any action in this repository.

---

## What this repository is

`Hermes-ACC` is the Administration Control Center for the Hermes / AI-agent infrastructure.
It is the single source of truth for VPS configuration, Docker containers, Hermes runtime,
credentials metadata, deployment scripts, and operational runbooks.

**Companion repo:** `hermes-agents` contains agent implementation code (prompts, skills, source).
`Hermes-ACC` references `hermes-agents` but never absorbs implementation code.

---

## Behavioral contract (mandatory)

### Reading

1. YAML in `inventory/`, `agents/`, `credentials/` is authoritative. Trust it over anything inferred.
2. Read runbooks in `runbooks/` before executing any operation.
3. Use `scripts/` for execution. Never invent shell incantations when a script exists.
4. Never ask the operator for data already documented in this repo. Search first.

### Writing

5. Never commit plaintext secrets. Pre-commit hooks will block it. Do not bypass with `--no-verify`.
6. Every YAML file you create must start with `schema_version: "1.0"`.
7. Update inventory, runbooks, and credential registry after every infrastructure change.
   A task is not complete until the repo reflects the new reality. This is a blocking rule.
8. Structural changes, scripts, secrets workflow changes, and anything affecting recovery
   require a feature branch and PR. Never push directly to `main` except for doc-only fixes.
9. Use descriptive commit messages: `feat:`, `fix:`, `docs:`, `chore:`, `secops:`.

### Credentials

10. Never invent credentials. If a credential is needed, look it up in
    `credentials/credential-registry.yaml`. If it is not there, stop and ask.
11. Never hard-code API keys, tokens, passwords, or private keys.
12. Secrets are encrypted via sops + age. See `secrets/README.md` for the workflow.
13. The age private identity is never in this repo. It lives on the operator workstation
    and VPS at `/home/hermesctl/.config/sops/age/keys.txt`.

### Destructive operations

14. Always run with `DRY_RUN=1` first. Every write/deploy/restore script supports this flag.
    Read-only scripts (`healthcheck.sh`, `validate-repo.sh`) are safe to run directly.
15. STOP and ask before:
    - Purging containers or deleting volumes
    - Rotating or revoking credentials
    - Changing SSH access or firewall rules
    - Running any restore over a running production environment

---

## Infrastructure quick reference

| Variable | Value |
|---|---|
| VPS host | See `inventory/servers.yaml` → `public_ip` |
| VPS admin user | `hermesctl` |
| Container name | See `inventory/containers.yaml` → `name` |
| Hermes image | See `inventory/containers.yaml` → `image` |
| HERMES_HOME (in container) | `/opt/data` |
| Hermes project (in container) | `/opt/hermes` |
| Telegram home chat ID | `8615165545` (config, not secret) |
| Host port | See `inventory/ports.yaml` |

---

## Repository layout

```
inventory/    ← YAML state (authoritative)
agents/       ← Agent manifests
vps/          ← VPS documentation and bootstrap
docker/       ← Compose files and container docs
hermes/       ← Hermes runtime documentation
credentials/  ← Credential metadata (no raw secrets)
secrets/      ← sops-encrypted files + bootstrap guide
templates/    ← Placeholder templates
scripts/      ← Shell scripts (write/deploy scripts support DRY_RUN=1)
runbooks/     ← Step-by-step procedures
checks/       ← Verification procedures
schemas/      ← JSON Schema for YAML validation
docs/         ← Architecture and design decisions
```

---

## After completing a task, always report

1. What changed (list of files modified or created)
2. What files were updated for inventory/documentation parity
3. What verification was run and its result
4. What remains manual or deferred (with explicit reason)

Failure to update documentation after an infrastructure change is a blocking error.

---

## Key runbooks

| Scenario | Runbook |
|---|---|
| Fresh VPS build | `runbooks/new-vps-from-zero.md` |
| Full redeploy | `runbooks/full-redeploy-fresh-vps.md` |
| Corrupted container | `runbooks/rebuild-corrupted-container.md` |
| Broken config | `runbooks/broken-hermes-config.md` |
| Rotate a credential | `runbooks/rotate-api-key.md` |
| Lost age key | `runbooks/lost-age-key.md` |
| Lost SSH key | `runbooks/lost-ssh-key.md` |
| Telegram bot issue | `runbooks/telegram-bot-issue.md` |
| Restore from backup | `runbooks/restore-from-backup.md` |
| Add a new agent | `runbooks/add-new-agent.md` |
