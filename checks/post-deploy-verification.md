# Post-deploy verification checklist

Run after every deploy, restore, or VPS bootstrap.

## Checklist

### Container health
- [ ] `bash scripts/healthcheck.sh` exits 0
- [ ] `docker ps` shows container in "Up" state, not "Restarting"
- [ ] No error spikes in `docker logs --tail=20 hermes-agent-m5gt-hermes-agent-1`

### Telegram gateway
- [ ] Send `/ping` from Telegram home chat (`8615165545`) — agent responds
- [ ] Check `hermes/telegram-gateway.md` — confirm mode (polling/webhook) is working

### Firewall
- [ ] `sudo ufw status` matches `inventory/ports.yaml`
- [ ] SSH (port 22) is accessible
- [ ] Hermes port (32768) is accessible from outside if required

### Secrets
- [ ] `/run/hermes/.env` exists on VPS with `chmod 600`
- [ ] No `.env` file committed in repo: `git log --oneline -1` looks clean

### Inventory parity
- [ ] `inventory/containers.yaml` reflects the currently running container
- [ ] `inventory/servers.yaml` reflects the current VPS IP/hostname

---

All checks passed? Deployment is complete and verified.

Any check failed? Consult the relevant runbook in `runbooks/`.
