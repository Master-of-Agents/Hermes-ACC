# Telegram gateway

## Configuration

| Field | Value |
|---|---|
| Bot token | Encrypted in `secrets/hermes.env.enc.yaml` → `TELEGRAM_BOT_TOKEN` |
| Home chat ID | `8615165545` (config, not secret — operator's personal channel) |
| Mode | Polling (assumed MVP) or webhook — confirm from Hermes config |

## How it works

Hermes connects to Telegram using the bot token. The home chat ID `8615165545`
is the primary operator channel where the agent receives and sends messages.
No other chat IDs receive agent responses by default.

## Verifying the gateway

From the home chat, send:
```
/ping
```
Hermes should respond. If it does not, see `runbooks/telegram-bot-issue.md`.

You can also check with `scripts/healthcheck.sh` which probes port 4860 and
optionally sends a Telegram test message.

## Webhook vs polling

- **Polling** (MVP default): Hermes polls the Telegram API; no inbound port needed beyond the container API port.
- **Webhook**: Telegram pushes updates to Hermes; requires the host port (32768) to be reachable from Telegram servers and a valid HTTPS endpoint. If switching to webhook, update `inventory/ports.yaml` and `vps/firewall-ufw.md`.

## Bot rotation

If the bot token is compromised or needs rotation:
1. See `runbooks/telegram-bot-issue.md`.
2. BotFather → `/revoke` → new token.
3. `sops secrets/hermes.env.enc.yaml` — update `TELEGRAM_BOT_TOKEN`.
4. `bash scripts/deploy-hermes.sh` — re-renders `.env` and restarts.
5. Update `credentials/credential-registry.yaml → TELEGRAM_BOT_TOKEN → last_rotated`.

## Recovery if bot is unresponsive

See `runbooks/telegram-bot-issue.md`.
