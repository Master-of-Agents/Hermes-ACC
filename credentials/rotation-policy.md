# Credential rotation policy

## Default rotation cadence

| Credential type | Scheduled rotation | Immediate rotation trigger |
|---|---|---|
| Telegram bot token | 180 days | Any suspicion of leak; bot behaving unexpectedly |
| LLM provider API keys (OpenRouter, Anthropic) | 90 days | Unexpected spend spike; any suspicion of leak |
| SSH login key (VPS) | 365 days | Operator workstation lost or compromised |
| GitHub deploy key | 365 days | Compromised GitHub account; deploy key exposed |
| age primary identity | 365 days | VPS compromised; workstation lost; any suspicion |
| age recovery identity | 365 days | Primary identity rotated or lost |

## Rotation procedure

1. Identify the credential in `credentials/credential-registry.yaml`.
2. Check `required_by` to know what will be affected.
3. Follow `runbooks/rotate-api-key.md` (generic) or the credential-specific runbook.
4. Update `last_rotated` in `credentials/credential-registry.yaml` after rotation.
5. Revoke the old credential immediately after the new one is confirmed working.

## Emergency rotation

If a credential is confirmed leaked or the system is compromised:

1. Revoke immediately via the provider dashboard — do not wait.
2. Update the sops-encrypted file with the new credential.
3. Redeploy Hermes.
4. Update `credentials/credential-registry.yaml`.
5. File a post-incident note in `docs/design-decisions.md`.

## Access review

Quarterly access review procedure: `credentials/access-review.md`.
