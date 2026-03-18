#!/bin/bash
# router-control: discover.sh
# Auto-discover home router and LAN topology
# Output: JSON to stdout, human-readable to stderr
set -euo pipefail

STATE_DIR="${HOME}/.lan-control"
STATE_FILE="${STATE_DIR}/state.json"
mkdir -p "$STATE_DIR"

# --- Detect OS ---
OS="$(uname -s)"

# --- Find default gateway (= router IP) ---
get_gateway() {
  case "$OS" in
    Darwin)
      route -n get default 2>/dev/null | awk '/gateway:/ {print $2}'
      ;;
    Linux)
      ip route show default 2>/dev/null | awk '/default/ {print $3; exit}'
      ;;
    *)
      echo ""
      ;;
  esac
}

ROUTER_IP=$(get_gateway)
if [ -z "$ROUTER_IP" ]; then
  echo '{"error": "no_gateway", "message": "Could not detect default gateway"}' 
  exit 1
fi

>&2 echo "🔍 Default gateway: $ROUTER_IP"

# --- Check for fake IPs (VPN/TUN interfaces) ---
# Common fake-ip ranges used by Clash, Surge, etc.
is_fake_ip() {
  local ip="$1"
  case "$ip" in
    198.18.*|198.19.*) echo "clash_fakeip" ;;
    100.64.*|100.65.*|100.66.*|100.67.*) echo "cgnat" ;;
    10.10.0.*|10.0.0.*) echo "vpn_tunnel" ;;
    *) echo "" ;;
  esac
}

FAKE=$(is_fake_ip "$ROUTER_IP")
if [ -n "$FAKE" ]; then
  >&2 echo "⚠️  Gateway $ROUTER_IP looks like a $FAKE address, not a real router"
  >&2 echo "   Scanning common router subnets..."
  
  # Try common router IPs
  for candidate in 192.168.1.1 192.168.0.1 192.168.8.1 192.168.31.1 10.0.0.1 172.16.0.1; do
    if ping -c 1 -W 1 "$candidate" >/dev/null 2>&1; then
      >&2 echo "   ✅ Found: $candidate"
      ROUTER_IP="$candidate"
      break
    fi
  done
fi

# --- Get local subnet info ---
get_local_ip() {
  case "$OS" in
    Darwin)
      # Get IP on the same subnet as the router
      local router_prefix
      router_prefix=$(echo "$ROUTER_IP" | cut -d. -f1-3)
      ifconfig 2>/dev/null | grep "inet " | awk '{print $2}' | grep "^${router_prefix}\." | head -1
      ;;
    Linux)
      ip -4 addr show 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1
      ;;
  esac
}

LOCAL_IP=$(get_local_ip)
>&2 echo "📡 Local IP: ${LOCAL_IP:-unknown}"

# --- Probe router services ---
SSH_OPEN=false
SSH_BANNER=""
HTTP_OPEN=false
HTTPS_OPEN=false
HTTP_TITLE=""
ROUTER_MODEL="unknown"

# SSH check
if nc -z -w 2 "$ROUTER_IP" 22 2>/dev/null; then
  SSH_OPEN=true
  SSH_BANNER=$(echo "" | nc -w 2 "$ROUTER_IP" 22 2>/dev/null | head -1 || true)
  >&2 echo "🔑 SSH: open ($SSH_BANNER)"
  
  # Detect router type from SSH banner
  case "$SSH_BANNER" in
    *dropbear*|*Dropbear*)  ROUTER_MODEL="OpenWrt (Dropbear)" ;;
    *OpenSSH*)              ROUTER_MODEL="Linux (OpenSSH)" ;;
    *Tailscale*)            ROUTER_MODEL="Tailscale SSH" ;;
  esac
else
  >&2 echo "🔑 SSH: closed"
fi

# HTTP check
if nc -z -w 2 "$ROUTER_IP" 80 2>/dev/null; then
  HTTP_OPEN=true
  # Try to get router model from HTTP response
  HTTP_RESP=$(curl -s -m 3 -o /dev/null -w "%{redirect_url}" "http://${ROUTER_IP}/" 2>/dev/null || true)
  HTTP_TITLE=$(curl -s -m 3 "http://${ROUTER_IP}/" 2>/dev/null | sed -n 's/.*<[Tt][Ii][Tt][Ll][Ee]>\([^<]*\)<.*/\1/p' | head -1 || true)
  
  # Identify by HTTP fingerprint
  if [ -n "$HTTP_TITLE" ]; then
    case "$HTTP_TITLE" in
      *GL.iNet*|*GL-*)      ROUTER_MODEL="GL.iNet" ;;
      *OpenWrt*|*LuCI*)     ROUTER_MODEL="OpenWrt" ;;
      *ASUS*|*RT-*)         ROUTER_MODEL="ASUS" ;;
      *TP-LINK*|*TP-Link*)  ROUTER_MODEL="TP-Link" ;;
      *Xiaomi*|*MiWiFi*)    ROUTER_MODEL="Xiaomi" ;;
      *Ubiquiti*|*UniFi*)   ROUTER_MODEL="Ubiquiti" ;;
      *Synology*)           ROUTER_MODEL="Synology" ;;
      *Netgear*|*NETGEAR*)  ROUTER_MODEL="Netgear" ;;
    esac
  fi
  >&2 echo "🌐 HTTP: open (title: ${HTTP_TITLE:-none})"
else
  >&2 echo "🌐 HTTP: closed"
fi

# HTTPS check  
if nc -z -w 2 "$ROUTER_IP" 443 2>/dev/null; then
  HTTPS_OPEN=true
fi

# --- Additional model detection via SSH if possible ---
# Some routers expose model in /etc/board.json or /tmp/sysinfo/model
# This will be done in connect.sh after SSH is established

# --- Build result ---
cat > "$STATE_FILE" << EOJSON
{
  "router_ip": "$ROUTER_IP",
  "local_ip": "${LOCAL_IP:-unknown}",
  "router_model": "$ROUTER_MODEL",
  "ssh": {
    "open": $SSH_OPEN,
    "banner": "$SSH_BANNER",
    "port": 22
  },
  "http": {
    "open": $HTTP_OPEN,
    "https": $HTTPS_OPEN,
    "title": "${HTTP_TITLE:-}"
  },
  "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "os": "$OS"
}
EOJSON

>&2 echo ""
>&2 echo "✅ Router discovered: $ROUTER_IP ($ROUTER_MODEL)"
>&2 echo "   State saved to: $STATE_FILE"

cat "$STATE_FILE"
