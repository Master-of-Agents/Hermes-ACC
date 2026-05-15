# Disaster recovery drill log

Audit record of disaster recovery drills. Each entry shows what was
exercised, what failed, and what was fixed afterwards.

A drill that passes without finding bugs is not a complete drill — it
means the runbook is too coarse to expose them. The drill is doing its
job when it surfaces friction.

---

## 2026-05-15 — Drill 2: full identity recovery (Atlatus) on clean-slate VPS

**Operator:** primary-admin
**Drill VPS:** `srv1670888.hstgr.cloud` (`187.127.85.205`), Hostinger KVM 1, freshly reinstalled Ubuntu 24.04.4 LTS
**Target agent:** Atlatus identity restored to drill bot `@uet_atldrill2_bot`
**Duration:** ~3 hours (with extensive doc updates between findings)
**Runbook followed:** `runbooks/new-vps-from-zero.md` post-2026-05-14 revision
**Outcome:** PASS — drill bot demonstrably inherits Atlatus's learned user preferences (Berlin timezone). Five new findings, all fixed in code or documentation before drill end.

### Phases executed

| Phase | Status |
|---|---|
| 1. Provision (OS reinstall, no SSH pre-upload — discipline upgrade vs Drill 1) | ✅ |
| 2. First access via Hostinger web console, install operator pubkey | ✅ |
| 3. Break-glass (hermesctl, ssh hardening, fresh GitHub deploy key) | ✅ |
| 4. Place primary age private key from Bitwarden | ✅ |
| 5. Clone repo, run `bootstrap-vps.sh` | ✅ (yesterday's docker-group fix held: clean exit 75, idempotent re-run after re-login) |
| 6. Hermes setup wizard with drill bot token override | ✅ |
| 6.5 Drill variant: read-only deploy key, restore from `hermes-state-atlatus` | ✅ after fixes #3 and #4 |
| 7. Install gateway systemd service | ✅ (no gateway.log permission issue — wizard answered `n` cleanly) |
| 8. Verification | ✅ |
| 9. Reboot test + restore validation | ✅ — drill bot replied `12:28:40 CEST` from Berlin tz preference |

### Findings

#### Finding 1 — Pre-uploaded SSH key in Phase 1 was a drill-killer shortcut
**Symptom (philosophical, not technical):** the earlier runbook said to upload the operator pubkey in the Hostinger panel before provisioning, so SSH worked from the start. That hides the realistic clean-slate scenario where no key exists yet.
**Fix:** rewrote Phase 1 + Phase 2 to enforce web-console-first access, with explicit "do NOT pre-upload an SSH key" discipline note. Phase 2 now walks through installing the operator pubkey from inside the web console.
**Commit:** `9e17f69`

#### Finding 2 — Wrong SSH key selected when connecting to a non-default VPS
**Symptom:** `ssh hermesctl@76.13.145.144` from a workstation that had the drill key as default prompted for a password (which doesn't exist) and gave no helpful error.
**Root cause:** with multiple VPSes, the default SSH key is whichever one the workstation was last set up for. The non-matching VPS rejects it and falls through to password auth, which is disabled — endless prompt.
**Fix:** updated `vps/ssh-access-model.md` with the per-VPS operator-key mapping and a mandatory `~/.ssh/config` recommendation (`Host ops`, `Host drill`, etc.). Pitfall added to runbook.
**Commit:** `41b45fb`

#### Finding 3 — Backup script was missing the agent's user-profile memories ⭐
**Symptom:** drill bot restored from `hermes-state-atlatus` had no memory of Berlin timezone — kept answering in UTC.
**Root cause:** `backup-agent-state.sh` only copied SOUL.md, skills/, cron/, state.db, config.yaml. It missed `/opt/data/memories/USER.md` (the learned user profile — where timezone, named entities, preferences live) plus `channel_directory.json` and `gateway_state.json`. The agent's "personality memory" was never being backed up.
**Fix:** added memories/, channel/gateway state to the backup set. Switched state.db copy to atomic SQLite `.backup` so concurrent writes can't produce a torn snapshot.
**Commit:** `527e222`

#### Finding 4 — `docker cp dir container:dest-dir` nests instead of merges
**Symptom:** after restoring memories/, the file landed at `/opt/data/memories/memories/USER.md` instead of `/opt/data/memories/USER.md`. Agent couldn't find it.
**Root cause:** when the destination is an existing directory, `docker cp` copies the source directory INTO it (creating a subdirectory) rather than replacing it. Same bug also nested `skills/` and `cron/` on Drill 1 — silently — masking the depth of the problem.
**Fix:** Phase 6.5 step 4 in the runbook now uses the `src/.` (contents) syntax with explicit `rm -rf` + `mkdir` of the destination first, with an inline explanation of the trap. Pitfall section in the runbook updated.

#### Finding 5 — `systemctl restart hermes-gateway` after restore is sometimes insufficient
**Symptom:** even after the files were in the right place, the drill bot kept answering UTC. A `sudo reboot` was required for the agent to actually pick up the new state.
**Root cause:** in-memory session/cache state in the gateway process can mask freshly-restored disk state. The gateway's prompt-cache TTL is 5 minutes; session idle timeout is 24 hours. A clean container restart bypasses all of that.
**Fix:** Phase 6.5 step 4 now ends with `sudo reboot` (not `systemctl restart`) to force a clean cycle. Both verification steps run after the reboot.

### What was demonstrably proven

- Bootstrap from clean-slate VPS works end-to-end with no manual fixups required.
- An agent's full identity (SOUL, skills, learned profile, scheduled jobs, channel mappings, conversation continuity via state.db) survives transplant to a fresh VPS.
- The `hermes-state-{name}` per-agent backup pattern is fit-for-purpose for personality recovery, not just for bootstrap config.

### Artifacts to clean up after drill
- [ ] Delete `AtlDrill2` bot in @BotFather
- [ ] Delete `srv1670888 (drill 2)` deploy key from `Master-of-Agents/Hermes-ACC`
- [ ] Delete `srv1670888 drill restore (read-only)` deploy key from `Master-of-Agents/hermes-state-atlatus`
- [ ] Decommission `srv1670888` VPS (or hold for Drill 3)
- [ ] Rotate the primary age key (partial prefix was accidentally echoed during diagnostics; mathematically still secure but discipline-first)

### Next drill due
Recommended: within 60 days, or after any major change to the backup or restore paths. Targeted goal: under 60 minutes from "press order" to "bot replies with restored personality."

---

## 2026-05-14 — Founding agent (Atlatus) recovery drill

**Operator:** primary-admin
**Drill VPS:** `srv1670888.hstgr.cloud` (`187.127.85.205`), Hostinger KVM 1, Ubuntu 24.04.4 LTS
**Target agent:** Atlatus (founding agent — `@uet_atltemp_bot` as drill-specific bot)
**Duration:** ~90 minutes from order-VPS to gateway-running-after-reboot
**Runbook followed:** `runbooks/new-vps-from-zero.md` (revision prior to this commit)
**Outcome:** PASS — five blocking bugs found and fixed/documented before the drill completed

### Phases executed

| Phase | Status |
|---|---|
| 1. Provision VPS in Hostinger panel, upload operator pubkey | ✅ |
| 2. Break-glass: create `hermesctl`, install pubkey, harden SSH | ✅ |
| 3. Place primary age private key from Bitwarden | ✅ |
| 4. Clone repo, run `bootstrap-vps.sh` | ✅ (after fix #1) |
| 5. Run Hermes setup wizard | ✅ (after fix #2) |
| 6. Install `hermes-gateway.service` | ✅ (after fix #3) |
| 7. Verification (healthcheck, ufw, systemctl) | ✅ 4/4 |
| 8. Reboot test | ✅ bot responded without manual intervention |

### Findings (in discovery order)

#### Finding 1 — `install-docker.sh` silently skipped `usermod -aG docker`
**Symptom:** `bootstrap-vps.sh` step 7 failed with `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`.
**Root cause:** Hostinger's Ubuntu 24.04 image ships with Docker pre-installed. The previous `install-docker.sh` early-exited if `docker --version` succeeded — skipping the `usermod -aG docker` call further down. `hermesctl` was never added to the group.
**Fix:** Restructured `install-docker.sh` to keep the group-membership check unconditional. If the user was just added, exits 75 so `bootstrap-vps.sh` halts cleanly and prompts re-login.
**Commit:** `c61bab2`

#### Finding 2 — xAI HTTP 400 with reasoning models
**Symptom:** Telegram messages reached the gateway, but every LLM call to `grok-3-mini` failed with `HTTP 400`. Request debug dump showed `include: ["reasoning.encrypted_content"]` in the payload — same parameter that broke us with OpenAI earlier.
**Root cause:** The xAI API key being used had lost (or never had) access to the encrypted-reasoning feature path that Hermes sends for reasoning models. The production agent worked at one point with the same key — feature access can change silently.
**Fix:** Generated a fresh xAI key in the xAI console; reran `hermes setup model` with the new key. Reasoning calls succeeded.
**Documentation:** Added to runbook pre-flight checklist and "Common pitfalls" section.

#### Finding 3 — `/opt/data/logs/gateway.log` permission error on first start
**Symptom:** `hermes-gateway.service` exited status 1 with `PermissionError: [Errno 13] Permission denied: '/opt/data/logs/gateway.log'`. The file existed but was owned by root, while the gateway runs as the `hermes` user inside the container.
**Root cause:** During the wizard, the operator confirmed "y" to a "start gateway" prompt that runs as root in some path. That created `gateway.log` as root. Subsequent systemd runs (correctly using `-u hermes`) couldn't write to it.
**Fix in drill:** `docker exec hermes-agent chown hermes:hermes /opt/data/logs/gateway.log; systemctl restart hermes-gateway`.
**Documentation:** Pitfall added to runbook. Long-term fix (preventing the root-owned file in the first place) deferred — happens once per fresh volume, easy to detect.

#### Finding 4 — `/run/hermes/.env` is overwritten on every gateway restart
**Symptom:** The drill bot needed a different `TELEGRAM_BOT_TOKEN` than production. Manual `sed` to override in `/run/hermes/.env` worked until the next `systemctl restart hermes-gateway`, which re-rendered the file from sops with the production token.
**Root cause:** Working as designed — the gateway service's `ExecStartPre` re-renders the env from sops to guarantee the sops file is authoritative. Manual edits to the rendered file are not persistent.
**Mitigation in drill:** Set the drill token via the wizard's `/opt/data/.env` write (persists in volume). Hermes reads that file in addition to env, so the drill token survives env_file overwrite.
**Documentation:** Pitfall + design note added to runbook.

#### Finding 5 — Drill bot vs production bot collision on the same sops file
**Symptom:** Two VPSes polling Telegram with the same bot token cause race conditions / rate-limiting.
**Root cause:** The sops file is bot-specific (one TELEGRAM_BOT_TOKEN per repo). The drill VPS using the production sops file would inevitably collide with production.
**Mitigation in drill:** Created a separate drill bot in `@BotFather` (`AtlTemp` / `@uet_atltemp_bot`), used its token only in `/opt/data/.env` on the drill VPS.
**Documentation:** Drill-specific guidance added to runbook (only relevant for drills, not real recovery).

### Recovery time
- Total wall-clock from "press order VPS button" to "bot survives reboot": ~90 minutes
- Of which: ~25 minutes was diagnosing and fixing the five findings above
- Steady-state recovery (no new bugs): expect 45–60 minutes

### Artifacts to clean up after drill
- [ ] Delete `AtlTemp` bot in @BotFather
- [ ] Delete the `srv1670888 (drill)` deploy key from `Master-of-Agents/Hermes-ACC`
- [ ] Decommission `srv1670888` VPS (or keep for next drill)
- [ ] Remove `Hermes Docker Founding Agent` and stale OpenAI Bitwarden entries (already done during drill)

### Next drill due
Recommended: within 90 days, or any time after a significant change to the bootstrap path / runbook.
