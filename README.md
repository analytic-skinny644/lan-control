# lan-control

> **Turn your home router into a universal device control hub.**  
> Zero config · Auto-discover · YAML device profiles · Community-driven · Local-first

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg?style=flat-square)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/Python-3.8+-green.svg?style=flat-square)](https://www.python.org)
[![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-blue.svg?style=flat-square)](https://github.com/openclaw/openclaw)

A CLI tool that turns **any SSH-accessible router** into a device discovery and control hub — LG TV, BroadLink IR, Android boxes, cameras, and [many more](#supported-devices) — powered by DHCP table scanning and community-maintained YAML device profiles.

---

## Table of Contents

- [Highlights](#highlights)
- [Quick Start](#quick-start)
- [Supported Devices](#supported-devices)
- [Built-in Commands](#built-in-commands)
- [Add Your Device](#add-your-device)
- [How It Works](#how-it-works)
- [Anti-patterns We Handle](#anti-patterns-we-handle)
- [License](#license)

---

## Highlights

- **Universal** — Not tied to any router brand. Works with OpenWrt, GL.iNet, ASUS Merlin, TP-Link, Xiaomi, Ubiquiti.
- **Zero config** — Auto-discovers your router (default gateway + SSH fingerprint + HTTP probe). No manual IP entry.
- **YAML-driven** — Each device type is a `.yaml` file. Adding support = adding a file. No code changes.
- **Community-driven** — MAC prefix + hostname pattern matching. Drop a YAML, submit a PR, done.
- **Local-first** — Runs on your Mac/Linux. No cloud, no VPS, no account. Your router, your data.
- **Agent-ready** — All output is structured JSON (stdout). Human summaries go to stderr.

## Quick Start

```bash
git clone https://github.com/ythx-101/lan-control.git
cd lan-control
pip install pyyaml   # only dependency
```

```bash
python3 cli.py discover                    # Find your router
python3 cli.py devices                     # List all LAN devices
python3 cli.py commands lg-webos           # Show available commands
python3 cli.py health                      # Router health check
```

Example output:

```
$ python3 cli.py discover
🔍 Default gateway: 192.168.1.1
🔑 SSH: open (SSH-2.0-dropbear)
✅ Router: GL-AXT1800 (OpenWrt 23.05)

$ python3 cli.py devices
📱 4 devices found:
  📺 192.168.1.100  LG webOS TV          ssap
  🎛️ 192.168.1.101  BroadLink RM4        http
  📷 192.168.1.102  Reolink Camera       http
  📦 192.168.1.103  Android TV Box       adb

$ python3 cli.py commands lg-webos
  power_off     关机
  volume_up     音量+
  launch_app    启动应用 [youtube, netflix, ...]
  set_volume    设置音量 (0-100)
  screenshot    截屏
  ...18 commands total
```

## Supported Devices

| Type | Devices | Protocol | Status |
|------|---------|----------|--------|
| **Router** | OpenWrt, GL.iNet, ASUS Merlin, TP-Link, Xiaomi, Ubiquiti | SSH | ✅ Verified |
| **TV** | LG webOS, Samsung Tizen, Roku | WebSocket/HTTP | ✅ Verified |
| **IR Remote** | BroadLink RM4, Tuya IR | UDP/HTTP | ✅ Verified |
| **Android Box** | H616/H618/S905/RK3566 | ADB/SSH | ✅ Verified |
| **Speaker** | Google Nest, Amazon Echo | Cast/HTTP | 📝 Community |
| **Camera** | Reolink, Hikvision | HTTP | 📝 Community |
| **AC** | Generic IR (via BroadLink) | IR Bridge | ✅ Verified |
| **IoT** | ESP/Tuya, Tasmota | HTTP/MQTT | 📝 Community |

> **✅ Verified** = tested on real hardware. **📝 Community** = profile contributed, PRs welcome to verify.

## Built-in Commands

| Command | Description |
|---------|-------------|
| `discover` | Auto-detect router (gateway → SSH → HTTP fingerprint) |
| `devices` | Scan DHCP table, match against device profiles |
| `commands <device>` | List available commands for a device type |
| `run <command>` | Execute command on router |
| `health` | Router health (memory, WireGuard, DNS, device ping) |
| `ping <ip\|hostname>` | Check if a device is online |

## Add Your Device

Your device isn't listed? **5 minutes:**

### 1. Create a YAML file

```yaml
# devices/tv/my-smart-tv.yaml
device:
  name: "My Smart TV"
  type: tv
  vendor: MyBrand
  protocol: http

discovery:
  mac_prefixes:
    - "aa:bb:cc"           # First 3 bytes of MAC
  hostname_patterns:
    - "(?i)mysmartv"       # Regex for DHCP hostname

connection:
  method: http
  port: 8080

commands:
  power_off:
    description: "Power off"
    action: "POST /api/power/off"
  volume_up:
    description: "Volume +"
    action: "POST /api/volume/up"
```

### 2. Test

```bash
python3 cli.py supported    # Your device should appear
```

### 3. Submit PR

That's it. The registry auto-scans all YAML files in `devices/`.

## How It Works

```
Router (OpenWrt/GL.iNet/...)
   │
   │  SSH → cat /tmp/dhcp.leases
   │
   ▼
lan-control
   │
   │  MAC prefix + hostname → match devices/*.yaml
   │
   ▼
Identified devices → native protocol commands
   📺 LG TV      → WebSocket (SSAP)
   🎛️ BroadLink  → UDP/HTTP
   📷 Camera     → HTTP API
   📦 Android    → ADB
```

```
devices/             ← Community contributes HERE
  router/            OpenWrt, GL.iNet, ASUS, TP-Link
  tv/                LG webOS, Samsung Tizen, Roku
  ir-remote/         BroadLink, Tuya IR
  speaker/           Google Nest, Amazon Echo
  camera/            Reolink, Hikvision
  iot/               Android Box, ESP/Tuya, Tasmota
  _schema.yaml       Template for new devices
registry.py          ← Auto-scans devices/
cli.py               ← CLI entry point
scripts/             ← Shell scripts (discover, connect, health)
```

## Anti-patterns We Handle

| Trap | What happens | Solution |
|------|-------------|----------|
| Clash/Surge fake IP | Gateway shows 198.18.0.1 (TUN) | Auto-detect fake-ip range, find real gateway |
| ISP port blocking | WireGuard on 51820 silently fails | Documented diagnosis + port change |
| Double NAT | Router WAN is private 192.168.x.x | Detection + bridge mode guidance |
| Router OOM | Services crash with <512MB RAM | Swap setup on external storage |
| Dropbear SSH | Different auth flow than OpenSSH | Multi-method auth (key → password → defaults) |

## License

[Apache-2.0](LICENSE)
