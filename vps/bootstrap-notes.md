# VPS bootstrap notes — manual break-glass steps

These are the one-time manual steps required before `scripts/bootstrap-vps.sh` can run.
They must be performed by the operator from the Hostinger web console or as the initial
root SSH session.

**These steps are intentionally manual.** They establish the baseline access that
automation depends on.

---

## Step 1: Initial root access

Use the Hostinger web console or root SSH credentials from the provider welcome email.

```bash
ssh root@76.13.145.144
```

## Step 2: Create the hermesctl admin user

```bash
adduser --disabled-password --gecos "" hermesctl
usermod -aG sudo hermesctl

# Passwordless sudo (MVP — revisit if second operator is added)
echo "hermesctl ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-hermesctl
chmod 0440 /etc/sudoers.d/90-hermesctl
visudo -c  # verify syntax
```

## Step 3: Install operator's SSH public key

```bash
install -d -m 0700 -o hermesctl -g hermesctl /home/hermesctl/.ssh

# Paste the operator's PUBLIC key (see vps/ssh-access-model.md for the fingerprint)
cat > /home/hermesctl/.ssh/authorized_keys << 'PUBKEY'
ssh-ed25519 AAAA...OPERATOR_PUBLIC_KEY... operator@workstation
PUBKEY

chown hermesctl:hermesctl /home/hermesctl/.ssh/authorized_keys
chmod 600 /home/hermesctl/.ssh/authorized_keys
```

## Step 4: Place the GitHub deploy key

The deploy key (ed25519 private key, generated separately — see `vps/ssh-access-model.md`)
must be placed on the VPS. Preferred method: copy directly from the operator workstation.

```bash
# From operator workstation — copy the key file directly:
scp ~/.ssh/id_ed25519_hermes_acc hermesctl@76.13.145.144:/home/hermesctl/.ssh/id_ed25519_hermes_acc
ssh hermesctl@76.13.145.144 'chmod 600 ~/.ssh/id_ed25519_hermes_acc'

# Configure SSH to use this key for GitHub (run on VPS as hermesctl):
cat >> /home/hermesctl/.ssh/config << 'SSHCONFIG'
Host github.com
  IdentityFile ~/.ssh/id_ed25519_hermes_acc
  StrictHostKeyChecking accept-new
SSHCONFIG
```

If `scp` is not available, use the Hostinger web console to paste the key content
into `/home/hermesctl/.ssh/id_ed25519_hermes_acc` using `nano`, then `chmod 600` it.
The key is a standard OpenSSH private key file (ed25519 format).

## Step 5: Harden SSH

```bash
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload ssh

# Verify: from another terminal, confirm hermesctl SSH works BEFORE closing root session
```

## Step 6: Place the age private identity

Before running `bootstrap-vps.sh`, copy the age private key from the operator workstation:

```bash
# From operator workstation:
ssh hermesctl@76.13.145.144 'mkdir -p ~/.config/sops/age'
scp ~/.config/sops/age/keys.txt hermesctl@76.13.145.144:/home/hermesctl/.config/sops/age/keys.txt
ssh hermesctl@76.13.145.144 'chmod 600 ~/.config/sops/age/keys.txt'
```

See `secrets/README-age-key-bootstrap.md` for the full age key setup procedure.

---

## After break-glass: hand off to scripts

Once the above steps are complete, run as `hermesctl`:

```bash
bash ~/Hermes-ACC/scripts/bootstrap-vps.sh
```

See `runbooks/new-vps-from-zero.md` for the full ordered procedure.
