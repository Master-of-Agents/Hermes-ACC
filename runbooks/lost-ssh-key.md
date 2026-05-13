# Runbook: Lost SSH key

**Purpose:** Restore SSH access to the VPS when the operator SSH private key is lost or the workstation is unavailable.

**Immediate safety:** If loss is due to theft or compromise, revoke immediately via Hostinger console.

---

## Steps

### 1. Access VPS via Hostinger console

Go to Hostinger web panel → VPS → Emergency console (or VNC).
This gives root-level access without SSH.

### 2. Generate a new SSH key pair (on a trusted workstation)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_hermes_vps_new -C "hermesctl@workstation-new"
```

### 3. Add the new public key to the VPS

Via Hostinger console (as root or via sudo):

```bash
# Add new key:
echo "ssh-ed25519 AAAA...NEW_KEY... hermesctl@new-workstation" \
  >> /home/hermesctl/.ssh/authorized_keys

# Remove the old/compromised key (identify by fingerprint):
# View current keys:
cat /home/hermesctl/.ssh/authorized_keys
# Delete the line matching the old fingerprint
```

### 4. Verify new key works

```bash
ssh -i ~/.ssh/id_ed25519_hermes_vps_new hermesctl@VPS_HOST
```

### 5. Update documentation

Update `vps/ssh-access-model.md` with the new fingerprint.
Update `credentials/credential-registry.yaml → VPS_SSH_LOGIN_KEY → last_rotated`.

---

## Verification

SSH login succeeds with the new key. Old key is no longer in `authorized_keys`.

## Post-conditions (docs to update)

- `vps/ssh-access-model.md` — new fingerprint
- `credentials/credential-registry.yaml` — `last_rotated`

## Rollback

N/A — key rotation is the fix itself.
