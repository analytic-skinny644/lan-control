#!/bin/bash
# router-control: ping.sh <ip|hostname>
# Check if a device is online (by IP or DHCP hostname lookup)
set -euo pipefail

STATE_FILE="${HOME}/.openclaw/router-control/state.json"
TARGET="${1:?Usage: ping.sh <ip|hostname>}"

if [ ! -f "$STATE_FILE" ]; then
  >&2 echo "❌ Not connected. Run discover.sh && connect.sh first."
  exit 1
fi

ROUTER_IP=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['router_ip'])")

# If target looks like a hostname, resolve via DHCP leases
if ! echo "$TARGET" | grep -qP '^\d+\.\d+\.\d+\.\d+$'; then
  >&2 echo "🔍 Looking up '$TARGET' in DHCP leases..."
  RESOLVED=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${ROUTER_IP}" \
    "grep -i '$TARGET' /tmp/dhcp.leases 2>/dev/null | awk '{print \$3}' | head -1" 2>/dev/null)
  
  if [ -z "$RESOLVED" ]; then
    >&2 echo "❌ '$TARGET' not found in DHCP leases"
    exit 1
  fi
  >&2 echo "   Resolved to: $RESOLVED"
  TARGET="$RESOLVED"
fi

# Ping from router (device might not be reachable from local machine)
RESULT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${ROUTER_IP}" \
  "ping -c 3 -W 2 '$TARGET' 2>&1" 2>/dev/null)

echo "$RESULT"

if echo "$RESULT" | grep -q "0% packet loss\|0 packets lost"; then
  echo '{"ip": "'$TARGET'", "status": "online"}'
else
  echo '{"ip": "'$TARGET'", "status": "offline"}'
fi
