# SSH access model

## Principles

- Key-based authentication only. Password SSH is disabled on every VPS.
- One operator SSH key per VPS, generated fresh during that VPS's
  break-glass phase. **Keys are not shared across VPSes.** Limits blast
  radius if a key file leaks.
- Keys are ed25519. RSA keys are not accepted.
- Root SSH login is disabled after break-glass completes.
- All active operator-to-VPS mappings are documented below.
- Rotate yearly, or immediately on any suspicion of compromise.

## Active operator keys

| VPS | IP | Operator key file (workstation) | Fingerprint | Added |
|---|---|---|---|---|
| `srv1663264` (production) | 76.13.145.144 | `~/.ssh/id_ed25519_hermes_vps` | `SHA256:eg8DLsLPs6wsi5rTUUCSFcdv92zpfPWSLVYrN2gOGho` | 2026-05-14 |
| `srv1670888` (drill) | 187.127.85.205 | `~/.ssh/id_ed25519_hostinger_vps2` (key comment `hostinger.vps2@sapxl.com`) | (regenerated each drill) | 2026-05-15 |

> When you regenerate the drill key, update its row here.

## Recommended workstation SSH config

With multiple VPSes, **always** maintain `~/.ssh/config` on your
workstation so the right key is selected automatically. Without it, the
SSH client tries default keys and falls through to a password prompt
when the wrong key is used — which is what failed during the 2026-05-15
drill (no key found → indefinite password prompt → confusion).

Example `~/.ssh/config`:

```sshconfig
Host ops
  HostName 76.13.145.144
  User hermesctl
  IdentityFile ~/.ssh/id_ed25519_hermes_vps
  IdentitiesOnly yes

Host drill
  HostName 187.127.85.205
  User hermesctl
  IdentityFile ~/.ssh/id_ed25519_hostinger_vps2
  IdentitiesOnly yes
```

Then `ssh ops` connects to production with the correct key,
`ssh drill` connects to the drill VPS. No `-i` flag required, no
ambiguity, no password fallback.

**Add a new `Host` block whenever you provision a new VPS.**

## SSH config on each VPS

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

## GitHub deploy keys

Each VPS uses its own SSH deploy key for cloning `Hermes-ACC`
(read-only). Keys are **not** shared between VPSes.

| VPS | Key file (on VPS) | Fingerprint | Added |
|---|---|---|---|
| `srv1663264` (production) | `/home/hermesctl/.ssh/id_ed25519_hermes_acc` | `SHA256:1G2orYJBMubVYfc/aHPEpbN0e8d4OzVLe0QvIJQ7aIU` | 2026-05-13 |
| `srv1670888` (drill 2) | `/home/hermesctl/.ssh/id_ed25519_hermes_acc` | `SHA256:Hp4X4G8iLpD1XMw9CLC3lcAJHk/ZJPoDyT3GHGrAVIo` | 2026-05-15 |

Registry entry: `credentials/credential-registry.yaml → GITHUB_INTEGRATION`.

Drill deploy keys are deleted from GitHub after the drill ends.

## Key rotation procedure

1. Generate a new ed25519 key on the workstation or VPS (depending on
   which side rotated).
2. Upload the new public key to its target:
   - For operator-on-workstation key, if SSH still works:
     `ssh-copy-id -i ~/.ssh/id_ed25519_new.pub hermesctl@VPS_HOST`
   - For deploy keys: GitHub → repo Settings → Deploy keys → Add.
   - If locked out of the VPS: use the Hostinger web console.
3. Verify the new key works.
4. Remove the old key from `authorized_keys` (or GitHub).
5. Update the fingerprint table above.
6. Update `credentials/credential-registry.yaml → last_rotated`.

## Emergency access

If all SSH keys to a VPS are lost: use the Hostinger web console
terminal (browser-based). See `runbooks/new-vps-from-zero.md` Phase 2
for the same flow as a fresh-install recovery.
