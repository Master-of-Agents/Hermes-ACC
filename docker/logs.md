# Container logs

## Log driver

All containers use the `json-file` driver with rotation:
- `max-size: 10m` per file
- `max-file: 5` (50 MB total per container before oldest rotated out)

This is configured in `docker/docker-compose.hermes.yml`.

## Viewing logs

```bash
# Live tail:
docker logs -f hermes-agent-m5gt-hermes-agent-1

# Last 100 lines:
docker logs --tail=100 hermes-agent-m5gt-hermes-agent-1

# Since a timestamp:
docker logs --since="2026-05-13T00:00:00" hermes-agent-m5gt-hermes-agent-1
```

## Log location on host

```
/var/lib/docker/containers/<container-id>/<container-id>-json.log
```

Use `docker inspect <container> | grep LogPath` to get the exact path.

## Log retention

Docker rotates log files automatically per the `max-file` setting.
Agent-level logs (inside `hermes_data`) are retained as long as the volume exists
and are included in daily backups.

## Log sensitivity

Container logs may include:
- Telegram message content
- LLM prompt/response fragments
- Error messages referencing credential names (but not values)

Do not commit or share log output without reviewing for sensitive content.
