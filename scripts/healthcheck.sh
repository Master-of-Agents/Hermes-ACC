#!/usr/bin/env bash
# Verify the Hermes agent container is running and healthy.
# Usage: bash scripts/healthcheck.sh
# Exit 0 = healthy, Exit 1 = unhealthy.
set -euo pipefail

CONTAINER_NAME="${HERMES_CONTAINER_NAME:-hermes-agent}"
HOST_PORT="${HERMES_PORT_HOST:-32768}"
CONTAINER_PORT="${HERMES_PORT_CONTAINER:-4860}"

PASS=0
FAIL=0

check() {
  local desc="$1"; local result="$2"
  if [[ "$result" == "ok" ]]; then
    echo "[PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $desc — $result"
    FAIL=$((FAIL + 1))
  fi
}

# 1. Container is running
RUNNING=$(docker inspect --format='{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
check "Container $CONTAINER_NAME is running" "$([[ "$RUNNING" == "true" ]] && echo ok || echo "not running")"

# 2. Container is not restarting
RESTARTING=$(docker inspect --format='{{.State.Restarting}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
check "Container not in restart loop" "$([[ "$RESTARTING" == "false" ]] && echo ok || echo "restarting=$RESTARTING")"

# 3. Host port is open
if bash -c "echo > /dev/tcp/localhost/$HOST_PORT" 2>/dev/null; then
  check "Host port $HOST_PORT is open" ok
else
  check "Host port $HOST_PORT is open" "port not responding"
fi

# 4. Container port responds from inside (bash /dev/tcp — nc not available in image)
INNER_HEALTH=$(docker exec "$CONTAINER_NAME" bash -c "echo > /dev/tcp/localhost/$CONTAINER_PORT && echo ok || echo fail" 2>/dev/null || echo "exec_failed")
check "Container port $CONTAINER_PORT responds inside container" "$INNER_HEALTH"

echo ""
echo "Result: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
