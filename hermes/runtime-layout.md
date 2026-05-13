# Hermes runtime layout

## Container filesystem

| Path | Purpose | Writable? |
|---|---|---|
| `/opt/hermes` | Hermes project root (image baked) | No (ro) |
| `/opt/data` | HERMES_HOME — persistent state | Yes (rw, named volume) |
| `/run/hermes/.env` | Rendered runtime secrets (tmpfs preferred) | tmpfs |

## HERMES_HOME contents (`/opt/data`)

| Path | Purpose | Backed up? |
|---|---|---|
| `/opt/data/config.yaml` | Main Hermes configuration | Yes |
| `/opt/data/auth.json` | Telegram and OAuth tokens | Yes (encrypted) |
| `/opt/data/sessions/` | Conversation sessions | Yes |
| `/opt/data/memory/` | Long-term agent memory | Yes |
| `/opt/data/skills/` | Loaded skill packs | Yes |
| `/opt/data/logs/` | Agent-level operation logs | Yes (optional) |
| `/opt/data/profiles/` | Agent profile files | Yes |

## Environment variables consumed by Hermes

See `templates/.env.hermes.example` for the full list with comments.
Key variables:

| Variable | Purpose |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Bot authentication (from sops) |
| `TELEGRAM_HOME_CHAT_ID` | Primary operator channel (`8615165545`) |
| `OPENROUTER_API_KEY` | LLM routing (optional — not configured, omit for MVP) |
| `ANTHROPIC_API_KEY` | Direct Claude API (from sops) |
| `HERMES_HOME` | Set to `/opt/data` by image defaults |

## Hermes version

The current image is `ghcr.io/hostinger/hvps-hermes-agent:latest`.
Pin to a digest when a stable release is identified (Phase 2+ roadmap).
See `inventory/containers.yaml` for the current tag.
