# Current containers — human-readable snapshot

Machine-readable authoritative data: `inventory/containers.yaml`.
This file is a human-readable summary for quick reference.

---

## hermes-agent (active)

| Field | Value |
|---|---|
| Container name | hermes-agent-m5gt-hermes-agent-1 |
| Image | ghcr.io/hostinger/hvps-hermes-agent:latest |
| Host | srv1663264 (76.13.145.144) |
| Restart policy | unless-stopped |
| Host port | 32768 |
| Container port | 4860 |
| Volume | hermes_data → /opt/data |
| Compose file | docker/docker-compose.hermes.yml |
| Status | active |

### Runtime paths (inside container)

| Path | Purpose |
|---|---|
| `/opt/hermes` | Hermes project root |
| `/opt/data` | HERMES_HOME — persistent state, config, token stores |

### Notes

Container was initially started ad-hoc by Hostinger provisioning.
Migration to `docker-compose.hermes.yml` is Phase 2 of the roadmap.
See `runbooks/rebuild-corrupted-container.md` for migration + recovery steps.
