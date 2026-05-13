# Runbook: Lost age private key

**Purpose:** Recover the ability to decrypt sops secrets when the primary age private key is lost.

**Immediate safety:** If loss circumstances are suspicious (stolen workstation, compromised system), treat ALL sops secrets as potentially exposed. Plan to rotate everything after recovery.

---

## Symptoms

- `sops -d secrets/hermes.env.enc.yaml` fails with "no key that matches any recipient"
- Age key file missing or corrupt: `~/.config/sops/age/keys.txt`

---

## Option A — Use the offline recovery identity (best path)

If a second recipient (recovery identity) was added to `secrets/.sops.yaml`:

```bash
# On a secure machine with the offline recovery key:
export SOPS_AGE_KEY_FILE=/path/to/offline/recovery-keys.txt
sops -d secrets/hermes.env.enc.yaml   # verify decryption works

# Generate a new primary identity:
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
# Note the new public key from stderr

# Update secrets/.sops.yaml with the new primary public key.
# Then re-key all encrypted files:
sops updatekeys secrets/hermes.env.enc.yaml
```

Commit the updated `.sops.yaml` and `.enc.yaml`. Copy the new `keys.txt` to the VPS.

## Option B — Retrieve from password manager

Retrieve the private key from Bitwarden/KeePass/1Password.
Paste the text (including header/footer) into `~/.config/sops/age/keys.txt`.
`chmod 600 ~/.config/sops/age/keys.txt`.

## Option C — Retrieve from paper/USB offline copy

Retrieve the sealed envelope from the physical safe.
Type or scan the key into `~/.config/sops/age/keys.txt`.

## Option D — All copies lost (worst case)

Every sops-encrypted secret is permanently unrecoverable.

1. Re-issue all credentials from scratch:
   - New Telegram bot token via @BotFather
   - New OpenRouter API key
   - New Anthropic API key
   - New GitHub deploy key
2. `age-keygen -o ~/.config/sops/age/keys.txt` — new primary identity
3. `age-keygen` — new recovery identity, store offline
4. Update `secrets/.sops.yaml` with new public keys
5. `sops secrets/hermes.env.enc.yaml` — create fresh with new credentials
6. Commit, deploy, verify

---

## Post-recovery (all options)

- Update `credentials/credential-registry.yaml → AGE_IDENTITY_PRIVATE_PRIMARY → last_rotated`
- Store new key backups offline immediately (don't wait)
- If loss was suspicious: rotate every downstream credential

## Prevention

This scenario is prevented by maintaining at least two offline copies of the age private key.
See `secrets/README-age-key-bootstrap.md` for the backup procedure.
