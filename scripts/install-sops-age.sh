#!/usr/bin/env bash
# Install sops and age (pinned versions) on Ubuntu/Debian x86_64.
# Usage: DRY_RUN=1 bash scripts/install-sops-age.sh
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
SOPS_VERSION="${SOPS_VERSION:-3.9.1}"
AGE_VERSION="${AGE_VERSION:-1.2.1}"

run() { if [[ "$DRY_RUN" == "1" ]]; then echo "DRY: $*"; else "$@"; fi; }

# age
if command -v age &>/dev/null && [[ "$DRY_RUN" != "1" ]]; then
  echo "age already installed: $(age --version 2>&1 | head -1)"
else
  echo "Installing age ${AGE_VERSION}..."
  run sudo apt-get install -y age 2>/dev/null || {
    # Fallback: download release binary
    run sudo curl -fsSL \
      "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" \
      -o /tmp/age.tar.gz
    run tar -xzf /tmp/age.tar.gz -C /tmp
    run sudo install -m 0755 /tmp/age/age /usr/local/bin/age
    run sudo install -m 0755 /tmp/age/age-keygen /usr/local/bin/age-keygen
    run rm -rf /tmp/age /tmp/age.tar.gz
  }
fi

# sops
if command -v sops &>/dev/null && [[ "$DRY_RUN" != "1" ]]; then
  echo "sops already installed: $(sops --version 2>&1 | head -1)"
else
  echo "Installing sops ${SOPS_VERSION}..."
  run sudo curl -fsSL \
    "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" \
    -o /usr/local/bin/sops
  run sudo chmod +x /usr/local/bin/sops
fi

if [[ "$DRY_RUN" != "1" ]]; then
  echo "age: $(age --version 2>&1 | head -1)"
  echo "sops: $(sops --version 2>&1 | head -1)"
fi
