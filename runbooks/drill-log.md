# Disaster recovery drill log

Audit record of disaster recovery drills. Each entry shows what was
exercised, what failed, and what was fixed afterwards.

A drill that passes without finding bugs is not a complete drill — it
means the runbook is too coarse to expose them. The drill is doing its
job when it surfaces friction.

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
