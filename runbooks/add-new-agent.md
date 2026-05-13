# Runbook: Add a new agent

**Purpose:** Onboard a new AI agent into the Hermes-ACC registry with proper documentation, permissions, and access.

**Preconditions:**
- Agent concept approved by operator
- Platform decided (hermes-runtime, claude-code, etc.)
- Required credentials identified

---

## Steps

### 1. Create agent manifest in Hermes-ACC

Copy `templates/agent-manifest.template.yaml` to `agents/<agent-name>.yaml`.
Fill in all fields per the schema in `schemas/agent.schema.json`.

Key decisions to make:
- `risk_level`: high if it has shell/infra access, low if read-only
- `allowed_operations`: specific list — do not use catch-all entries
- `forbidden_operations`: include at minimum: commit secrets, push to main, destructive ops without confirmation
- `credentials_required`: reference names from `credentials/credential-registry.yaml`

### 2. Add to agent registry

Add an entry to `agents/agent-registry.yaml`:

```yaml
- id: <agent-name>
  manifest: agents/<agent-name>.yaml
  status: planned  # or active once deployed
  platform: <platform>
  risk_level: <low|medium|high>
  owner: primary-admin
  summary: "<one-line description>"
```

### 3. Add credentials (if new ones are needed)

For each new credential:
1. Issue from provider
2. Add to `secrets/hermes.env.enc.yaml` via `sops secrets/hermes.env.enc.yaml`
3. Add metadata entry to `credentials/credential-registry.yaml`
4. Add placeholder to `templates/.env.hermes.example`

### 4. Create agent implementation in hermes-agents (separate repo)

The prompt text, skills, and workspace go in `hermes-agents`, not here.
Reference `agents/hermes-founding-agent.yaml → repository_ownership` as a model.

### 5. Open a PR for the manifest + registry changes

```bash
git checkout -b feat/add-<agent-name>
git add agents/ credentials/
git commit -m "feat: add <agent-name> manifest and registry entry"
git push origin feat/add-<agent-name>
# Open PR against main
```

### 6. After deployment — update status

Change `current_status: planned` to `current_status: active` in the manifest.
Update `agents/agent-registry.yaml` status.
Commit on main (doc-only).

---

## Verification

- Agent manifest validates: `bash scripts/validate-repo.sh schema-validate`
- Agent responds correctly in its designated channel
- Credentials work

## Post-conditions (docs to update)

- `agents/agent-registry.yaml`
- `agents/<agent-name>.yaml`
- `credentials/credential-registry.yaml` (if new credentials added)

## Rollback

Change `current_status: active` back to `planned`. Revoke any credentials issued for it.
