#!/bin/bash
# router-control: devices.sh
# List all LAN devices from router DHCP leases with type identification
set -euo pipefail

STATE_DIR="${HOME}/.lan-control"
STATE_FILE="${STATE_DIR}/state.json"

if [ ! -f "$STATE_FILE" ]; then
  >&2 echo "❌ Not connected. Run discover.sh && connect.sh first."
  exit 1
fi

ROUTER_IP=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['router_ip'])")

>&2 echo "📡 Scanning devices on $ROUTER_IP..."

# Get DHCP leases from router (try multiple paths for compatibility)
LEASES=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${ROUTER_IP}" '
  for f in /tmp/dhcp.leases /var/lib/misc/dnsmasq.leases /var/lib/misc/dnsmasq-dhcp.leases /tmp/dnsmasq.leases; do
    [ -f "$f" ] && cat "$f" && exit 0
  done
  echo ""
' 2>/dev/null)

if [ -z "$LEASES" ]; then
  >&2 echo "❌ No DHCP leases found"
  echo '[]'
  exit 1
fi

# Parse leases and identify devices
echo "$LEASES" | python3 - "$STATE_FILE" << 'PYEOF'
import json, sys, os, re
from datetime import datetime

STATE_FILE = sys.argv[1]

# MAC prefix → (vendor, device_type)
VENDORS = {
    "4c:ba:d7": ("LG", "smart_tv"),     "a8:23:fe": ("LG", "smart_tv"),
    "e8:70:72": ("BroadLink", "ir_remote"), "78:0f:77": ("BroadLink", "ir_remote"),
    "24:db:ed": ("BroadLink", "ir_remote"), "34:ea:34": ("BroadLink", "ir_remote"),
    "dc:a6:32": ("Raspberry Pi", "sbc"), "b8:27:eb": ("Raspberry Pi", "sbc"),
    "f0:2f:74": ("Google", "smart_speaker"), "20:df:b9": ("Google", "chromecast"),
    "74:6d:e4": ("Amazon", "echo"),      "fc:65:de": ("Amazon", "echo"),
    "14:91:82": ("Apple", "apple"),      "3c:22:fb": ("Apple", "apple"),
    "f8:ff:c2": ("Apple", "apple"),      "ac:bc:32": ("Apple", "apple"),
    "ac:cf:85": ("Tuya", "iot"),         "d8:f1:5b": ("Espressif", "iot"),
}

# Hostname regex → (type, display_name)
PATTERNS = [
    (r"(?i)LGwebOS|lg.*tv", "smart_tv", "LG TV"),
    (r"(?i)BroadLink|rm4", "ir_remote", "BroadLink"),
    (r"(?i)iphone", "phone", "iPhone"), (r"(?i)ipad", "tablet", "iPad"),
    (r"(?i)macbook|imac|mac.?mini|mac.?pro|mac.?studio", "computer", "Mac"),
    (r"(?i)galaxy|samsung", "phone", "Samsung"), (r"(?i)pixel", "phone", "Pixel"),
    (r"(?i)echo|alexa", "smart_speaker", "Echo"),
    (r"(?i)chromecast|google.?cast", "streaming", "Chromecast"),
    (r"(?i)roku", "streaming", "Roku"), (r"(?i)fire.?tv", "streaming", "FireTV"),
    (r"(?i)playstation|ps[345]", "console", "PlayStation"),
    (r"(?i)xbox", "console", "Xbox"), (r"(?i)switch|nintendo", "console", "Switch"),
    (r"(?i)printer|canon|epson|brother|hp.?jet", "printer", "Printer"),
    (r"(?i)camera|cam|hikvi|dahua|reolink", "camera", "Camera"),
    (r"(?i)raspberry|raspberrypi", "sbc", "Raspberry Pi"),
]

ICONS = {
    "smart_tv": "📺", "ir_remote": "🎛️", "phone": "📱", "tablet": "📱",
    "apple": "🍎", "computer": "💻", "smart_speaker": "🔊", "echo": "🔊",
    "chromecast": "📡", "streaming": "📡", "sbc": "🖥️", "iot": "💡",
    "console": "🎮", "printer": "🖨️", "camera": "📷",
}

devices = []
for line in sys.stdin.read().strip().split("\n"):
    parts = line.split()
    if len(parts) < 4:
        continue
    expiry, mac, ip, hostname = parts[0], parts[1].lower(), parts[2], parts[3]
    
    # Identify by MAC
    prefix = mac[:8]
    vendor, dtype = VENDORS.get(prefix, ("unknown", "unknown"))
    name = hostname if hostname != "*" else None
    
    # Override by hostname pattern
    for pat, pt, pn in PATTERNS:
        if hostname and re.search(pat, hostname):
            dtype, name = pt, name or pn
            break
    
    devices.append({"ip": ip, "mac": mac, "hostname": hostname if hostname != "*" else None,
                     "name": name, "type": dtype, "vendor": vendor})

devices.sort(key=lambda d: [int(x) for x in d["ip"].split(".")])

# Update state
if os.path.exists(STATE_FILE):
    state = json.load(open(STATE_FILE))
    state["devices"] = devices
    state["last_scan"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    json.dump(state, open(STATE_FILE, "w"), indent=2)

# JSON to stdout
print(json.dumps(devices, indent=2))

# Summary to stderr
print(f"\n📱 {len(devices)} devices found:", file=sys.stderr)
for d in devices:
    n = d["name"] or d["hostname"] or "?"
    icon = ICONS.get(d["type"], "❓")
    print(f"  {icon} {d['ip']:16s} {n:20s} {d['vendor']}", file=sys.stderr)
PYEOF
