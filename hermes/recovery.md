# Hermes recovery — quick index

This file indexes recovery runbooks for Hermes-specific failure scenarios.
See the linked runbooks for full step-by-step procedures.

| Scenario | Runbook |
|---|---|
| Container restarting / crashing | `runbooks/rebuild-corrupted-container.md` |
| Broken config after an edit | `runbooks/broken-hermes-config.md` |
| Telegram bot unresponsive | `runbooks/telegram-bot-issue.md` |
| Full VPS loss — rebuild from zero | `runbooks/full-redeploy-fresh-vps.md` |
| Data loss — restore from backup | `runbooks/restore-from-backup.md` |
| Corrupted Docker volume | `runbooks/restore-from-backup.md` → §10.7 |
| All credentials lost | `runbooks/rotate-api-key.md` + `runbooks/lost-age-key.md` |

## General principle

The golden path for any Hermes failure:

1. Check `scripts/healthcheck.sh` output.
2. Check `docker logs` for the container.
3. Check `hermes/runtime-layout.md` to verify volume and env are intact.
4. Follow the matching runbook above.
5. If unsure, start with `runbooks/rebuild-corrupted-container.md` — it covers the most common case.
