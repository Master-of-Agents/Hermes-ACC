# Runbook: Rotate an API key or token

**Purpose:** Safely rotate any credential tracked in `credentials/credential-registry.yaml`.

**Preconditions:**
- Age key available (`SOPS_AGE_KEY_FILE`)
- Access to the provider dashboard
- SSH access to VPS

---

## Steps

### 1. Identify affected components

Open `credentials/credential-registry.yaml` and find the credential.
Note the `required_by` field — these containers/scripts/agents will be affected.

### 2. Issue new credential from provider dashboard

| Credential | Provider location |
|---|---|
| TELEGRAM_BOT_TOKEN | @BotFather → /revoke (creates new) |
| ANTHROPIC_API_KEY | console.anthropic.com → API keys |
| GITHUB_INTEGRATION | GitHub → repo → Settings → Deploy keys |
| OPENROUTER_API_KEY | openrouter.ai → dashboard → API keys *(optional — not configured)* |

**Do not revoke the old credential yet.**

### 3. Update the sops-encrypted secrets file

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops secrets/hermes.env.enc.yaml
# Editor opens — update the relevant key value, save
```

### 4. Commit the updated encrypted file

```bash
git add secrets/hermes.env.enc.yaml
git commit -m "secops: rotate <CREDENTIAL_NAME>"
git push origin main  # or PR branch
```

### 5. Re-render the runtime .env and redeploy

```bash
bash scripts/render-env-from-sops.sh /run/hermes/.env
bash scripts/deploy-hermes.sh
```

### 6. Verify the new credential works

`bash scripts/healthcheck.sh`

For Telegram: send `/ping` from home chat.
For LLM keys: check agent can process a test message.

### 7. Revoke the old credential

Revoke the old key in the provider dashboard immediately after verifying the new one works.

### 8. Update the registry

```bash
# Update last_rotated in credentials/credential-registry.yaml:
# last_rotated: "YYYY-MM-DD"
git add credentials/credential-registry.yaml
git commit -m "docs: update last_rotated for <CREDENTIAL_NAME>"
```

---

## Verification

- Healthcheck passes
- Agent functional
- Old credential revoked in provider dashboard

## Post-conditions (docs to update)

- `credentials/credential-registry.yaml → last_rotated`
- Any entry where `revocation_procedure` was followed

## Rollback

If the new credential fails:
1. Re-issue a replacement from the provider.
2. Update sops file again.
3. Re-render and redeploy.

The old credential may already be revoked — do not try to un-revoke it.
