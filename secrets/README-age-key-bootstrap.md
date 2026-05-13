# Age key bootstrap guide

## The chicken-egg problem

Three things are needed to bring up a fresh VPS:

1. SSH access to clone Hermes-ACC (needs the deploy key)
2. The age private identity to decrypt sops secrets
3. The decrypted secrets to start the Hermes container

The age private identity must **not** live in the repository. So there is a
bootstrap step that cannot be automated: the operator must place the age private
identity on the VPS before automation can take over.

---

## First-time setup (operator workstation)

### 1. Generate an age key pair

```bash
# Creates ~/.config/sops/age/keys.txt with private key (print public key to stderr)
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# The public key looks like: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Copy it — you will put it in secrets/.sops.yaml
```

### 2. Generate a second (recovery) key pair for offline storage

```bash
age-keygen | tee /dev/stderr | grep "^AGE-SECRET-KEY" > /tmp/recovery-age-key.txt
# Store this key OFFLINE only (password manager, USB in safe, printed paper)
# The public key line will be: # public key: age1yyyyy...
# Add it as the second recipient in secrets/.sops.yaml
rm /tmp/recovery-age-key.txt   # delete from disk after storing offline
```

### 3. Update secrets/.sops.yaml

Replace the placeholder public keys:

```yaml
creation_rules:
  - path_regex: secrets/.*\.enc\.yaml$
    encrypted_regex: '^(.*_KEY|.*_TOKEN|.*_PASSWORD|.*_SECRET|.*_B64|data)$'
    age: >-
      age1PRIMARY_PUBLIC_KEY_HERE,
      age1RECOVERY_PUBLIC_KEY_HERE
```

Commit `.sops.yaml` (public keys are safe to commit).

### 4. Encrypt the secrets file with real values

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
sops secrets/hermes.env.enc.yaml
# Editor opens with placeholder content — replace REPLACE_WITH_SOPS_ENCRYPTED_VALUE
# with real values, then save. sops encrypts on close.
```

Commit the resulting `secrets/hermes.env.enc.yaml`.

---

## Fresh VPS bootstrap order

```
1. Operator SSHes into fresh VPS as hermesctl.
   (See vps/bootstrap-notes.md for how hermesctl is created.)

2. Operator copies the age private key to the VPS:
   scp ~/.config/sops/age/keys.txt \
       hermesctl@VPS_HOST:/home/hermesctl/.config/sops/age/keys.txt
   ssh hermesctl@VPS_HOST 'chmod 600 ~/.config/sops/age/keys.txt'

3. Operator or bootstrap script clones Hermes-ACC:
   git clone git@github.com:Master-of-Agents/Hermes-ACC.git ~/Hermes-ACC
   (Requires deploy key at ~/.ssh/id_ed25519_hermes_acc — placed before this step.)

4. Run scripts/render-env-from-sops.sh to produce /run/hermes/.env.

5. Run scripts/deploy-hermes.sh to start the container.

6. Run scripts/healthcheck.sh to verify.
```

---

## Recovery options if the primary age key is lost

Ranked by practicality:

### Option 1 — Use the offline recovery identity (recommended)
If you set up a second recipient (recovery identity) in `.sops.yaml`:
```bash
# On a secure machine with the recovery identity:
export SOPS_AGE_KEY_FILE="/path/to/offline/recovery-keys.txt"
sops -d secrets/hermes.env.enc.yaml  # decrypt with recovery identity

# Generate a new primary identity:
age-keygen -o ~/.config/sops/age/keys.txt

# Update .sops.yaml with new primary public key, then re-key:
sops updatekeys secrets/hermes.env.enc.yaml
```

### Option 2 — Use an offline password manager copy
Retrieve the private key text from Bitwarden/KeePass/1Password.
Paste into `~/.config/sops/age/keys.txt`. `chmod 600`.

### Option 3 — Paper/USB copy
Retrieve the printed private key from the physical safe. Type it in.

### Option 4 — If ALL copies are lost
All sops-encrypted secrets are unrecoverable. You must:
1. Re-issue every credential from scratch (new Telegram bot, new API keys, etc.)
2. Create a new age identity.
3. Re-encrypt a fresh `hermes.env.enc.yaml` with real values.
4. Redeploy.

**This is why maintaining at least two offline copies of the age private key is mandatory.**

---

## Backup the age private identity (required)

After generating your age keys, store the private key in at least two places:

- [ ] Password manager (Bitwarden, KeePass, 1Password) as a secure note
- [ ] Encrypted USB stick in a physical safe (or printed + sealed envelope)

The key material looks like:
```
# created: 2026-05-13T00:00:00Z
# public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```
