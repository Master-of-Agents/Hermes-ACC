# Firewall — UFW rules

## Policy

- Default: deny incoming, allow outgoing.
- Only explicitly allowed ports are open.
- UFW rules must match `inventory/ports.yaml` at all times.
- Never open a port without adding it to the inventory and this file.

## Active rules

```
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp      # SSH — operator access
ufw allow 32768/tcp   # Hermes agent API (maps to container port 4860)
ufw enable
```

## Current rule set (verify with `sudo ufw status verbose`)

| Port | Protocol | Direction | Purpose |
|---|---|---|---|
| 22 | TCP | in | SSH — operator and agent access |
| 32768 | TCP | in | Hermes agent (HERMES_PORT_HOST → container 4860) |

## Adding a port

1. Add a rule: `sudo ufw allow <PORT>/tcp comment '<purpose>'`
2. Add an entry to `inventory/ports.yaml`.
3. Update this file.
4. Commit the inventory change on a branch and open a PR.

## Removing a port

1. `sudo ufw delete allow <PORT>/tcp`
2. Remove the entry from `inventory/ports.yaml`.
3. Update this file.
4. Commit and PR.

## Emergency lockdown procedure

If the VPS is suspected compromised:

```bash
# Allow only your operator IP:
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw allow from YOUR_IP_HERE to any port 22 proto tcp
sudo ufw allow out to any port 443 proto tcp  # HTTPS for package updates
sudo ufw reload
```

Verify you still have SSH from a second terminal before running this.
See `runbooks/full-redeploy-fresh-vps.md` for what to do after lockdown.
