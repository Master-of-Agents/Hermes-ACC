# Hermes-ACC — Administration Control Center

Private GitHub repository. Single source of truth for administering the Hermes / AI-agent infrastructure.

**Companion repo (separate, agent implementation only):** [hermes-agents](https://github.com/Master-of-Agents/hermes-agents)

---

## What this repo is

`Hermes-ACC` contains everything needed to rebuild, operate, and recover the Hermes infrastructure:

- VPS inventory and bootstrap procedures
- Docker container definitions and compose files
- Hermes agent runtime configuration
- Telegram gateway documentation
- SSH access model
- Credential metadata (no raw secrets — see below)
- Encrypted secrets via sops + age
- Deployment, backup, and restore scripts
- Operational runbooks for every failure scenario
- Agent manifests and permission registry

## What this repo is NOT

- It is **not** a secret manager. Raw credentials must never be committed here.
- It does **not** contain agent implementation code (prompts, skills, source). That lives in [hermes-agents](https://github.com/Master-of-Agents/hermes-agents).
- It is **not** a general development workspace.

## Agent and operator entry points

| I want to… | Start here |
|---|---|
| Understand this repo | [`CLAUDE.md`](CLAUDE.md) |
| Rebuild a fresh VPS | [`runbooks/new-vps-from-zero.md`](runbooks/new-vps-from-zero.md) |
| Recover from a lost VPS | [`runbooks/full-redeploy-fresh-vps.md`](runbooks/full-redeploy-fresh-vps.md) |
| Recover a broken container | [`runbooks/rebuild-corrupted-container.md`](runbooks/rebuild-corrupted-container.md) |
| Rotate a credential | [`runbooks/rotate-api-key.md`](runbooks/rotate-api-key.md) |
| Set up secrets (age/sops) | [`secrets/README-age-key-bootstrap.md`](secrets/README-age-key-bootstrap.md) |
| See all infrastructure | [`inventory/`](inventory/) |
| See all agents | [`agents/agent-registry.yaml`](agents/agent-registry.yaml) |

## Repository structure

```
Hermes-ACC/
├── inventory/      ← YAML state: servers, containers, volumes, networks, ports
├── agents/         ← Agent manifests and permission registry
├── vps/            ← Per-host bootstrap notes, SSH/firewall model
├── docker/         ← Compose files and container documentation
├── hermes/         ← Hermes runtime layout, Telegram, config, recovery
├── credentials/    ← Credential metadata (NO raw secrets)
├── secrets/        ← sops-encrypted secret files + bootstrap guide
├── templates/      ← .example and .template files with placeholders
├── scripts/        ← Idempotent, dry-run-capable shell scripts
├── runbooks/       ← Step-by-step procedures for every scenario
├── checks/         ← Verification and drill procedures
├── schemas/        ← JSON Schema files validating YAML inventory
└── docs/           ← Architecture, glossary, design decisions
```

## Secrets policy

Raw secrets (API keys, tokens, SSH private keys, age private identities) are **never** committed here.

- Encrypted secrets live in `secrets/*.enc.yaml` (sops + age).
- Templates with placeholders live in `templates/`.
- The age private identity lives on the operator workstation and VPS only — never in this repo.
- See [`secrets/README.md`](secrets/README.md) for the full workflow.

## Repo boundary

This repo MUST NOT absorb agent implementation code. The rule:

| Belongs in `Hermes-ACC` | Belongs in `hermes-agents` |
|---|---|
| Infrastructure inventory | Agent source code / prompts |
| Deployment scripts | Skill packs |
| Credential metadata | Agent workspaces |
| Agent manifests (metadata) | Conversation logs |
| Runbooks and recovery | Runtime experiments |

## Security

- Private repository.
- Branch protection: PRs required for all changes except doc-only edits to `runbooks/` and `inventory/` READMEs.
- CODEOWNERS: primary admin reviews all PRs.
- Pre-commit hooks: gitleaks, detect-private-key, yamllint, shellcheck.
- See [`docs/architecture.md`](docs/architecture.md) for the full security posture.
