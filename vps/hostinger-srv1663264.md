# VPS: srv1663264 (Hostinger)

## Inventory reference

See `inventory/servers.yaml` → id: `srv1663264` for machine-readable facts.

## Provider details

| Field | Value |
|---|---|
| Provider | Hostinger |
| Hostname | srv1663264 |
| Public IP | 76.13.145.144 |
| Admin user | hermesctl |
| SSH port | 22 |
| OS | Ubuntu 22.04 LTS (assumption — verify at bootstrap) |
| Plan | REPLACE_WITH_PLAN_NAME |
| Region | REPLACE_WITH_REGION |
| Billing ref | REPLACE_WITH_BILLING_REFERENCE |

## Console access

Hostinger web panel → VPS → select this server.
Emergency root console is available via the web panel if SSH is locked out.

## Software installed

| Package | Version | Notes |
|---|---|---|
| Docker CE | see `install-docker.sh` | via official apt repo |
| Docker Compose plugin | see `install-docker.sh` | bundled with Docker CE |
| age | see `install-sops-age.sh` | for sops encryption |
| sops | see `install-sops-age.sh` | 3.9.1 or current pinned |
| ufw | system | firewall |
| git | system | apt |
| jq | system | JSON parsing in scripts |
| yq | see `bootstrap-vps.sh` | YAML parsing in scripts |

## Access model

See `vps/ssh-access-model.md` for SSH key inventory and rotation policy.
See `vps/firewall-ufw.md` for UFW rules.

## Notes

Container hosted here: `hermes-agent-m5gt-hermes-agent-1`
See `inventory/containers.yaml` for full container details.
