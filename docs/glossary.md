# Glossary

| Term | Definition |
|---|---|
| **ACC** | Administration Control Center — this repository |
| **age** | A simple, modern encryption tool used to encrypt/decrypt secrets |
| **agent** | An AI agent instance (Hermes Founding Agent, Claude Code, etc.) |
| **HERMES_HOME** | The persistent data directory for the Hermes agent (`/opt/data` inside the container) |
| **hermesctl** | The non-root admin user on the VPS with passwordless sudo and Docker group access |
| **hermes-agents** | The companion repository containing agent implementation code |
| **Hostinger** | The VPS cloud provider hosting `srv1663264` |
| **sops** | Secrets OPerationS — a tool that encrypts YAML/JSON files using age (or other backends) |
| **VPS_HOST** | The public IP of the current primary VPS (`76.13.145.144` for `srv1663264`) |
| **break-glass** | A manual one-time procedure performed before scripted automation can take over |
| **dry-run** | Running a script with `DRY_RUN=1` to print actions without executing them |
| **schema_version** | A required top-level field in every YAML inventory/manifest file indicating the schema revision |
| **deploy key** | An SSH key registered in a GitHub repo's settings, granting access to that specific repo only |
| **enc.yaml** | A sops-encrypted YAML file (ciphertext committed to the repo) |
| **quarantine volume** | A renamed Docker volume preserved during a restore — not deleted until restore is verified |
| **blast radius** | The scope of damage if a credential is leaked or compromised |
