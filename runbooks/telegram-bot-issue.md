# Runbook: Telegram bot issue

**Purpose:** Recover when the Hermes Telegram bot is unresponsive, erroring, or the token is suspected leaked.

---

## Symptoms

- No response to messages in the home chat (`8615165545`)
- `docker logs` shows Telegram API errors (401, 409, webhook failures)
- `bash scripts/healthcheck.sh` port check passes but Telegram is silent
- Unexpected messages sent from the bot (possible token compromise)

---

## Step 1 — Diagnose

```bash
docker logs --tail=50 hermes-agent-m5gt-hermes-agent-1 | grep -i telegram
bash scripts/healthcheck.sh
```

**Is the bot token confirmed leaked or suspicious?** Skip to "Emergency revocation" below.

## Step 2 — Container is running but bot is silent

Restart the container:
```bash
docker compose -f docker/docker-compose.hermes.yml restart
sleep 5
```

Send `/ping` from home chat. If no response:

```bash
docker logs --tail=20 hermes-agent-m5gt-hermes-agent-1
```

## Step 3 — Rotate the bot token (planned or emergency)

### 3a — Revoke current token

Open Telegram, message @BotFather:
```
/revoke
```
Select the Hermes bot. Copy the new token.

### 3b — Update sops encrypted file

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops secrets/hermes.env.enc.yaml
# Update TELEGRAM_BOT_TOKEN value, save
```

Commit: `git add secrets/hermes.env.enc.yaml && git commit -m "secops: rotate TELEGRAM_BOT_TOKEN"`

### 3c — Redeploy

```bash
bash scripts/render-env-from-sops.sh /run/hermes/.env
bash scripts/deploy-hermes.sh
```

### 3d — Verify

Send `/ping` from home chat (`8615165545`). Agent should respond.

## Emergency revocation (suspected compromise)

If unexpected messages are being sent:

1. **Immediately** message @BotFather → `/revoke`. This kills the token.
2. Verify unexpected messages stop.
3. Investigate: check `docker logs`, check if any other system has the token.
4. Follow steps 3a–3d to issue a new token.
5. Audit `secrets/hermes.env.enc.yaml` for any other indicators of compromise.

---

## Verification

`/ping` from home chat gets a response.

## Post-conditions (docs to update)

- `credentials/credential-registry.yaml → TELEGRAM_BOT_TOKEN → last_rotated`
- If a new failure mode: note in `hermes/telegram-gateway.md`

## Rollback

The old token was revoked — there is no rollback. The fix is the new token.
