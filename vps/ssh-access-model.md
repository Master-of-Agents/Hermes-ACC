# SSH access model

## Principles

- Key-based authentication only. Password SSH is disabled.
- One key per operator workstation. No shared keys.
- Keys are ed25519. RSA keys are not accepted.
- Root SSH login is disabled.
- All active key fingerprints are documented below.
- Rotate yearly or immediately on any suspicion.

## Active keys

| Holder | Type | Fingerprint | Added | Notes |
|---|---|---|---|---|
| primary-admin workstation | ed25519 | REPLACE_WITH_FINGERPRINT | REPLACE_WITH_DATE | Main operator key |

## SSH config on the VPS

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

## GitHub deploy key

The VPS uses a separate SSH deploy key for cloning Hermes-ACC:

- Key: `/home/hermesctl/.ssh/id_ed25519_hermes_acc`
- Public key registered in GitHub → Master-of-Agents/Hermes-ACC → Settings → Deploy keys
- Registry entry: `credentials/credential-registry.yaml → GITHUB_INTEGRATION`

## Key rotation procedure

1. Generate a new ed25519 key on the new workstation or after suspected compromise.
2. Upload the new public key to the VPS:
   - If SSH still works: `ssh-copy-id -i ~/.ssh/id_ed25519_new.pub hermesctl@VPS_HOST`
   - If locked out: use Hostinger web console to add the key directly.
3. Verify new key works.
4. Remove the old key from `/home/hermesctl/.ssh/authorized_keys`.
5. Update the fingerprint table above.
6. Update `credentials/credential-registry.yaml → VPS_SSH_LOGIN_KEY → last_rotated`.

## Emergency access

If all SSH keys are lost: use the Hostinger web console VPS terminal.
See `runbooks/lost-ssh-key.md` for the full recovery procedure.
