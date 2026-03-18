#!/bin/bash
# router-control: health.sh
# Quick health check: router status + device online check + DNS + VPN
set -euo pipefail

STATE_FILE="${HOME}/.openclaw/router-control/state.json"

if [ ! -f "$STATE_FILE" ]; then
  >&2 echo "❌ Not connected. Run discover.sh && connect.sh first."
  exit 1
fi

ROUTER_IP=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['router_ip'])")

>&2 echo "🏥 Health check on $ROUTER_IP..."

# Collect all info in one SSH call (minimize connections)
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@${ROUTER_IP}" '
echo "=== UPTIME ==="
uptime

echo "=== MEMORY ==="
free -m 2>/dev/null || cat /proc/meminfo | grep -E "MemTotal|MemAvail"

echo "=== DISK ==="
df -h / /tmp 2>/dev/null | tail -n +2

echo "=== DNS ==="
# Check what DNS server is configured
if [ -f /etc/config/dhcp ]; then
  uci get dhcp.@dnsmasq[0].server 2>/dev/null || echo "default"
fi

echo "=== WIREGUARD ==="
if command -v wg >/dev/null 2>&1; then
  wg show 2>/dev/null | grep -E "interface:|latest handshake:|transfer:" || echo "no WG interfaces"
else
  echo "not installed"
fi

echo "=== ADGUARD ==="
if pgrep -x AdGuardHome >/dev/null 2>&1; then
  echo "running"
  curl -s http://127.0.0.1:3000/control/status 2>/dev/null | grep -o '"running":true' || echo "api unreachable"
else
  echo "not running"
fi

echo "=== DEVICES ==="
cat /tmp/dhcp.leases 2>/dev/null || echo "no leases"

echo "=== DEVICE_PING ==="
# Ping each device to check online status
while read -r expiry mac ip hostname cid; do
  [ -z "$ip" ] && continue
  if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
    echo "ONLINE $ip $hostname"
  else
    echo "OFFLINE $ip $hostname"
  fi
done < /tmp/dhcp.leases 2>/dev/null
' 2>&1
