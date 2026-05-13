#!/usr/bin/env bash
# Local repo validation — runs without CI.
# Usage:
#   bash scripts/validate-repo.sh all              # full validation
#   bash scripts/validate-repo.sh schema-version   # check schema_version in YAML files
#   bash scripts/validate-repo.sh forbidden-paths  # check for forbidden filenames
#   bash scripts/validate-repo.sh schema-validate  # validate YAML against JSON schemas
set -euo pipefail

MODE="${1:-all}"
PASS=0
FAIL=0

ok()   { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }

check_schema_version() {
  echo "--- Checking schema_version in YAML inventory files ---"
  local checked=0
  while IFS= read -r -d '' f; do
    # Skip files where schema_version is not expected
    case "$f" in
      .yamllint|.pre-commit-config.yaml|secrets/.sops.yaml|\
      docker/docker-compose*|templates/docker-compose*) continue ;;
    esac
    if grep -q "^schema_version:" "$f" 2>/dev/null; then
      ok "$f has schema_version"
    else
      fail "$f is missing schema_version"
    fi
    checked=$((checked + 1))
  done < <(find inventory agents credentials -name "*.yaml" -print0 2>/dev/null)
  echo "(Checked $checked YAML files)"
}

check_forbidden_paths() {
  echo "--- Checking for forbidden paths/filenames ---"
  local found=0

  # Patterns that must never appear
  local patterns=(
    "*.env"
    "id_rsa" "id_ed25519" "id_ecdsa"
    "*.pem" "*.key"
    "*.dec" "*.decrypted" "*.plain"
    "age-identity*" "*.agekey" "age*.txt"
  )

  for pat in "${patterns[@]}"; do
    while IFS= read -r -d '' f; do
      # Allow .env.example and .env.*.example
      case "$f" in
        *.env.example|*.env.*.example|templates/*.env*) continue ;;
      esac
      fail "Forbidden file found: $f (matches pattern: $pat)"
      found=$((found + 1))
    done < <(find . -name "$pat" ! -path "./.git/*" -print0 2>/dev/null)
  done

  [[ "$found" -eq 0 ]] && ok "No forbidden paths found"
}

check_schema_validate() {
  echo "--- Validating YAML against JSON schemas ---"
  if ! command -v check-jsonschema &>/dev/null && ! command -v ajv &>/dev/null; then
    echo "SKIP: Neither check-jsonschema nor ajv found. Install with: pip install check-jsonschema"
    return
  fi

  local pairs=(
    "inventory/servers.yaml:schemas/server.schema.json"
    "inventory/containers.yaml:schemas/container.schema.json"
    "inventory/volumes.yaml:schemas/volume.schema.json"
    "credentials/credential-registry.yaml:schemas/credential.schema.json"
  )

  for pair in "${pairs[@]}"; do
    local yaml="${pair%%:*}"
    local schema="${pair##*:}"
    if [[ ! -f "$yaml" ]]; then continue; fi
    if command -v check-jsonschema &>/dev/null; then
      if check-jsonschema --schemafile "$schema" "$yaml" &>/dev/null; then
        ok "$yaml validates against $schema"
      else
        fail "$yaml fails schema validation ($schema)"
      fi
    fi
  done
}

case "$MODE" in
  schema-version)   check_schema_version ;;
  forbidden-paths)  check_forbidden_paths ;;
  schema-validate)  check_schema_validate ;;
  all)
    check_schema_version
    check_forbidden_paths
    check_schema_validate
    ;;
  *)
    echo "Unknown mode: $MODE. Use: all | schema-version | forbidden-paths | schema-validate" >&2
    exit 1
    ;;
esac

echo ""
echo "Validation result: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
