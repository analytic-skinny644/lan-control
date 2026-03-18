#!/bin/bash
# router-control: run.sh <command>
# Execute a command on the router via SSH
set -euo pipefail

STATE_FILE="${HOME}/.lan-control/state.json"

if [ ! -f "$STATE_FILE" ]; then
  >&2 echo "❌ Not connected. Run discover.sh && connect.sh first."
  exit 1
fi

ROUTER_IP=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['router_ip'])")
CMD="${*:?Usage: run.sh <command>}"

# Allowlist: only permit safe router commands
ALLOWED_CMDS="uptime|free|df|cat /tmp/dhcp.leases|wg show|iwinfo|ip addr|ip route|uci show|logread|dmesg|reboot|ping"
FIRST_WORD=$(echo "$CMD" | awk '{print $1}')
case "$FIRST_WORD" in
  uptime|free|df|cat|wg|iwinfo|ip|uci|logread|dmesg|reboot|ping) ;;
  *)
    >&2 echo "⚠️  Command '$FIRST_WORD' not in allowlist. Use with caution."
    >&2 echo "   Allowed: $ALLOWED_CMDS"
    if [ -t 0 ]; then
      read -r -p "   Continue? [y/N] " confirm
      case "$confirm" in [yY]*) ;; *) exit 1 ;; esac
    else
      exit 1
    fi
    ;;
esac

ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@${ROUTER_IP}" "$CMD" 2>&1
