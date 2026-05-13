# Architecture

## System overview

```
Operator (workstation)
  │
  ├─ SSH → hermesctl@srv1663264 (Hostinger VPS)
  │           │
  │           └─ Docker: hermes-agent container
  │                        │
  │                        ├─ Volume: hermes_data (/opt/data)
  │                        ├─ Port: 32768 → 4860
  │                        └─ .env: /run/hermes/.env (sops-rendered)
  │
  └─ Telegram ← → Hermes agent ← → LLM providers
                  (Telegram home chat: 8615165545)
```

## Repository boundary

```
Hermes-ACC (this repo)          hermes-agents (separate repo)
─────────────────────────────   ───────────────────────────────
VPS inventory                   Agent source code / prompts
Docker compose files            Skill packs
Credential metadata             Agent workspaces
Agent manifests (metadata)      Conversation logs
Runbooks                        Runtime experiments
Scripts
```

## Secrets model

```
secrets/hermes.env.enc.yaml     ← sops-encrypted, committed
        │
        │ sops -d (age key)
        ▼
/run/hermes/.env                ← plaintext, tmpfs, chmod 600, NOT committed
        │
        │ env_file in compose
        ▼
Hermes container environment
```

Age private key lives:
- Operator workstation: `~/.config/sops/age/keys.txt`
- VPS: `/home/hermesctl/.config/sops/age/keys.txt`
- Offline: password manager + hardware backup (required)

## Automation phases

See §12 of the concept document for the full Phase 0–7 roadmap.
Current phase: **Phase 0–1** (documentation + scripts).

## Security posture

See `docs/design-decisions.md` for current security decisions and trade-offs.
