#!/bin/bash
# router-control: run.sh <command>
# Execute a command on the router via SSH
set -euo pipefail

STATE_FILE="${HOME}/.openclaw/router-control/state.json"

if [ ! -f "$STATE_FILE" ]; then
  >&2 echo "❌ Not connected. Run discover.sh && connect.sh first."
  exit 1
fi

ROUTER_IP=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['router_ip'])")
CMD="${*:?Usage: run.sh <command>}"

ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@${ROUTER_IP}" "$CMD" 2>&1
