#!/bin/bash
# router-control: connect.sh [password]
# Establish SSH connection to router. Tries key → password → common defaults.
# Updates state.json with auth method.
set -euo pipefail

STATE_DIR="${HOME}/.openclaw/router-control"
STATE_FILE="${STATE_DIR}/state.json"

if [ ! -f "$STATE_FILE" ]; then
  >&2 echo "❌ No router discovered. Run discover.sh first."
  exit 1
fi

ROUTER_IP=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['router_ip'])" 2>/dev/null)
SSH_OPEN=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['ssh']['open'])" 2>/dev/null)
USER_PASSWORD="${1:-}"

if [ "$SSH_OPEN" != "True" ]; then
  >&2 echo "❌ SSH not open on $ROUTER_IP"
  exit 1
fi

>&2 echo "🔐 Connecting to $ROUTER_IP..."

# --- Try 1: SSH key auth ---
try_key_auth() {
  ssh -o StrictHostKeyChecking=no \
      -o ConnectTimeout=5 \
      -o BatchMode=yes \
      -o PreferredAuthentications=publickey \
      "root@${ROUTER_IP}" "echo KEY_AUTH_OK" 2>/dev/null
}

# --- Try 2: Password auth ---
try_password_auth() {
  local pw="$1"
  # Use expect if available, otherwise sshpass
  if command -v expect >/dev/null 2>&1; then
    expect -c "
      set timeout 10
      spawn ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o PreferredAuthentications=password -o NumberOfPasswordPrompts=1 root@${ROUTER_IP} echo PASS_AUTH_OK
      expect {
        \"assword:\" { send \"${pw}\r\" }
        \"(root@\" { send \"${pw}\r\" }
        timeout { exit 1 }
      }
      expect {
        \"PASS_AUTH_OK\" { exit 0 }
        \"ermission denied\" { exit 1 }
        \"onnection closed\" { exit 1 }
        timeout { exit 1 }
      }
    " 2>/dev/null | grep -q "PASS_AUTH_OK"
  elif command -v sshpass >/dev/null 2>&1; then
    sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${ROUTER_IP}" "echo PASS_AUTH_OK" 2>/dev/null | grep -q "PASS_AUTH_OK"
  else
    return 1
  fi
}

# --- Get router details after successful auth ---
get_router_info() {
  local method="$1"
  local pw="${2:-}"
  
  local ssh_cmd="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5"
  
  case "$method" in
    key) 
      INFO=$($ssh_cmd "root@${ROUTER_IP}" '
        echo "MODEL:$(cat /tmp/sysinfo/model 2>/dev/null || cat /proc/device-tree/model 2>/dev/null || uname -n)"
        echo "OS:$(cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_DESCRIPTION | cut -d= -f2 | tr -d "\"'" || uname -o)"
        echo "UPTIME:$(uptime)"
        echo "MEM:$(free -m 2>/dev/null | head -2 | tail -1 | awk "{print \$2}")"
      ' 2>/dev/null) ;;
    password)
      # For password auth, we just confirmed it works. Store the password hint.
      INFO="MODEL:$(echo "$ROUTER_IP" | sed 's/.*\./router/')\nOS:unknown" ;;
  esac
  
  echo "$INFO"
}

# --- Main connection flow ---
AUTH_METHOD=""
AUTH_PASSWORD=""

# Try 1: Key auth
>&2 echo "   Trying SSH key auth..."
if try_key_auth; then
  AUTH_METHOD="key"
  >&2 echo "   ✅ Key auth successful"
else
  >&2 echo "   ❌ Key auth failed"
  
  # Try 2: User-provided password
  if [ -n "$USER_PASSWORD" ]; then
    >&2 echo "   Trying provided password..."
    if try_password_auth "$USER_PASSWORD"; then
      AUTH_METHOD="password"
      AUTH_PASSWORD="$USER_PASSWORD"
      >&2 echo "   ✅ Password auth successful"
    else
      >&2 echo "   ❌ Password rejected"
    fi
  fi
  
  # Try 3: Common default passwords
  if [ -z "$AUTH_METHOD" ]; then
    >&2 echo "   Trying common defaults..."
    for pw in "" admin password root 12345678 admin123; do
      if try_password_auth "$pw"; then
        AUTH_METHOD="password"
        AUTH_PASSWORD="$pw"
        >&2 echo "   ✅ Default password worked: $([ -z "$pw" ] && echo "(empty)" || echo "****")"
        break
      fi
    done
  fi
fi

if [ -z "$AUTH_METHOD" ]; then
  >&2 echo ""
  >&2 echo "❌ Could not authenticate to $ROUTER_IP"
  >&2 echo "   Try: bash scripts/connect.sh \"your-password\""
  echo '{"error": "auth_failed", "router_ip": "'$ROUTER_IP'"}'
  exit 1
fi

# --- Get router details ---
>&2 echo "   Fetching router info..."
INFO=$(get_router_info "$AUTH_METHOD" "$AUTH_PASSWORD" 2>/dev/null || true)

MODEL=$(echo "$INFO" | grep "^MODEL:" | cut -d: -f2- | xargs || echo "unknown")
ROUTER_OS=$(echo "$INFO" | grep "^OS:" | cut -d: -f2- | xargs || echo "unknown")

# --- Update state ---
python3 << PYEOF
import json, os
state = json.load(open("$STATE_FILE"))
state["ssh_user"] = "root"
state["ssh_auth"] = "$AUTH_METHOD"
state["router_model"] = "$MODEL" if "$MODEL" != "unknown" else state.get("router_model", "unknown")
state["router_os"] = "$ROUTER_OS"
state["connected"] = True
json.dump(state, open("$STATE_FILE", "w"), indent=2)
print(json.dumps(state, indent=2))
PYEOF

>&2 echo ""
>&2 echo "✅ Connected to $ROUTER_IP ($MODEL)"
>&2 echo "   Auth: $AUTH_METHOD"
