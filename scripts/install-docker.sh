#!/usr/bin/env bash
# Install Docker CE and Docker Compose plugin on Ubuntu/Debian.
# Usage: DRY_RUN=1 bash scripts/install-docker.sh
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
run() { if [[ "$DRY_RUN" == "1" ]]; then echo "DRY: $*"; else "$@"; fi; }

# Idempotent: skip Docker install if already present (e.g. Hostinger images),
# but ALWAYS ensure the current user is in the docker group below.
if command -v docker &>/dev/null && [[ "$DRY_RUN" != "1" ]]; then
  echo "Docker already installed: $(docker --version)"
  echo "Skipping install — but checking group membership."
else
  echo "Installing Docker CE..."
  run sudo apt-get update -qq
  run sudo apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg lsb-release

  run sudo install -m 0755 -d /etc/apt/keyrings
  run sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc
  run sudo chmod a+r /etc/apt/keyrings/docker.asc

  CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  run bash -c "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu ${CODENAME} stable\" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null"

  run sudo apt-get update -qq
  run sudo apt-get install -y \
      docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
fi

# Ensure current user is in the docker group, whether Docker was just installed
# or was pre-installed by the cloud provider's base image.
if groups "$USER" | grep -qw docker; then
  echo "$USER is already in the docker group."
else
  echo "Adding $USER to the docker group..."
  run sudo usermod -aG docker "$USER"
  echo ""
  echo "  IMPORTANT: log out and back in for group membership to take effect,"
  echo "  then re-run bootstrap-vps.sh. The bootstrap is idempotent."
  echo ""
  # Exit non-zero so bootstrap-vps.sh halts cleanly and prompts the operator
  # rather than failing later with a confusing docker socket permission error.
  exit 75
fi
