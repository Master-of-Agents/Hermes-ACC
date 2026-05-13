# Runbook: YAML schema migration

**Purpose:** Handle a breaking schema change to any YAML file in `inventory/`, `agents/`, or `credentials/`.

**Preconditions:**
- The breaking change is understood and the new schema is defined
- All affected files are identified

---

## When this is needed

A breaking schema change is one that:
- Removes or renames a required field
- Changes the type of an existing field
- Splits one file format into two

Non-breaking additions (new optional fields) do not require this runbook.

---

## Steps

### 1. Bump schema_version in the JSON schema

Update `schemas/<affected>.schema.json`:
- Change the `$id` if a new schema file is warranted
- Add the new version constant

### 2. Update all affected YAML files

Find affected files:
```bash
grep -rl "^schema_version: \"1.0\"" inventory/ agents/ credentials/
```

For each file, apply the migration (rename fields, restructure, etc.).
Update `schema_version: "1.0"` to `schema_version: "1.1"` (or appropriate new version).

### 3. Update any scripts reading the YAML

Search for `yq` usage in `scripts/`:
```bash
grep -n "yq" scripts/*.sh
```

Update field paths to match the new schema.

### 4. Validate

```bash
bash scripts/validate-repo.sh all
```

### 5. Open a PR with the migration

```bash
git checkout -b secops/schema-migration-v1.1
git add inventory/ agents/ credentials/ schemas/ scripts/
git commit -m "chore: migrate YAML schema to v1.1 — <description of change>"
git push origin secops/schema-migration-v1.1
# Open PR
```

---

## Verification

`bash scripts/validate-repo.sh schema-validate` passes.
No scripts fail on the migrated YAML.

## Post-conditions

- All affected `schema_version` fields bumped
- `schemas/*.schema.json` updated
- Scripts updated if field paths changed
- A note added to `docs/design-decisions.md` explaining why the schema changed
