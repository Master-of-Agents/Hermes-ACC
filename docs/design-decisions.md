# Design decisions

Records of architectural decisions and their rationale.
New entries go at the top.

---

## 2026-05-13 — Initial scaffold (v1.0)

**Decision:** sops + age as the MVP secrets tool.
**Rationale:** Minimal tooling, no external service dependency, works offline, and encrypts files that can be committed to git. Alternatives (1Password CLI, Doppler, Infisical, Vault) can replace it later without changing the rest of the architecture.

**Decision:** Two-repo split (`Hermes-ACC` for infra/admin, `hermes-agents` for agent code).
**Rationale:** Prevents the admin repo from becoming a dumping ground for agent implementation. Clear boundary reduces blast radius if `hermes-agents` is compromised.

**Decision:** passwordless sudo for `hermesctl` in MVP.
**Rationale:** Single-operator setup; reduces friction during recovery operations. Must be revisited if a second human operator or high-risk agent gains shell access.

**Decision:** No GitHub Actions in MVP.
**Rationale:** Avoids CI secret exfiltration risk. Local pre-commit hooks (`gitleaks`, `yamllint`, `shellcheck`) provide equivalent protection without requiring secrets in CI.

**Decision:** PR required for all changes except doc-only edits.
**Rationale:** Provides a review checkpoint and audit trail. Doc-only edits to runbooks/inventory README files may go directly to main to avoid friction during incidents.

**Decision:** `schema_version: "1.0"` required in all YAML inventory files.
**Rationale:** Makes breaking changes detectable by scripts and agents. Avoids silent schema drift.

**Open questions / deferred decisions:**
- Offsite backup target (deferred to Phase 4)
- Future secret manager migration (deferred to Phase 5)
- Image pinning by digest (deferred to Phase 2+)

---

*Add new entries above this line in format: `## YYYY-MM-DD — Title`*
