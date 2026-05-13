# Secrets — sops + age workflow

This directory holds sops-encrypted secret files and age bootstrap documentation.

**Raw secrets are never committed here.** Only sops-encrypted ciphertext and workflow documentation.

---

## Files in this directory

| File | Purpose |
|---|---|
| `.sops.yaml` | sops creation rules — age recipients |
| `hermes.env.enc.yaml` | sops-encrypted Hermes runtime environment variables |
| `README-age-key-bootstrap.md` | How to set up age keys and recover on a fresh VPS |

---

## Quick reference

### Decrypt and view (read-only)
```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
sops -d secrets/hermes.env.enc.yaml
```

### Edit (decrypts in editor, re-encrypts on save)
```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
sops secrets/hermes.env.enc.yaml
```

### Generate runtime .env (for deployment)
```bash
bash scripts/render-env-from-sops.sh /run/hermes/.env
```

### Verify no plaintext secrets are staged
```bash
git diff --cached | gitleaks protect --staged --no-banner
```

---

## Must never be committed

- `~/.config/sops/age/keys.txt` (age private identity)
- Any decrypted `.env` file
- Decrypted backup archives
- Files matching `.dec`, `.decrypted`, `.plain`
- Any file with real API keys, tokens, or passwords

The `.gitignore` enforces this mechanically.

---

## Adding a new secret

1. `sops secrets/hermes.env.enc.yaml` — editor opens, decrypted.
2. Add the new key: `NEW_KEY: real_value`.
3. Save — sops re-encrypts automatically.
4. Add a metadata entry in `credentials/credential-registry.yaml`.
5. Add a placeholder in `templates/.env.hermes.example`.
6. Commit the updated `.enc.yaml` and registry.

## Adding a new recipient (e.g., second admin)

1. New admin generates their age key: `age-keygen -o ~/.config/sops/age/keys.txt`
2. Add their public key to `secrets/.sops.yaml` creation_rules.
3. Re-key every encrypted file:
   ```bash
   sops updatekeys secrets/hermes.env.enc.yaml
   ```
4. Commit the updated `.sops.yaml` and `.enc.yaml`.

## Removing a recipient

1. Remove the public key from `secrets/.sops.yaml`.
2. `sops updatekeys secrets/hermes.env.enc.yaml`.
3. **Rotate every credential** decryptable by the removed recipient — treat them as exposed.
4. Commit. Update `credentials/credential-registry.yaml` rotation dates.

---

See also: `secrets/README-age-key-bootstrap.md` for the chicken-egg bootstrap problem.
