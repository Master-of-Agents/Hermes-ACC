# Hermes configuration

## Configuration file

Main configuration: `/opt/data/config.yaml` (inside the container, in the `hermes_data` volume).

Hermes reads this file at startup. Changes require a container restart.

## Environment variables

Runtime secrets and environment are injected via `/run/hermes/.env` (rendered from sops).
See `templates/.env.hermes.example` for the full reference with comments.

## Configuration change workflow

1. Edit the config inside the container (or on the host volume path):
   ```bash
   docker exec -it hermes-agent-m5gt-hermes-agent-1 \
     vi /opt/data/config.yaml
   # or edit the volume directly:
   sudo vi /var/lib/docker/volumes/hermes_data/_data/config.yaml
   ```
2. Restart the container:
   ```bash
   docker compose -f docker/docker-compose.hermes.yml restart
   ```
3. Verify with `scripts/healthcheck.sh`.

If a config change breaks the agent, see `runbooks/broken-hermes-config.md`.

## Profiles

See `hermes/profiles.md` for profile configuration.

## Known configuration gotchas

- Hermes reads `HERMES_HOME` from the environment; if the volume is not mounted to `/opt/data`, the agent will fail to find config.
- The Telegram bot token must be set in `.env`, not hard-coded in config.yaml.
- Changing `TELEGRAM_HOME_CHAT_ID` requires a redeploy; it is a startup-time parameter.
