# Router Profiles

Auto-detection support for various router brands. The `discover.sh` script identifies routers by SSH banner and HTTP title.

## OpenWrt (Generic)

- **SSH**: Dropbear (port 22)
- **Web**: LuCI (port 80)
- **DHCP leases**: `/tmp/dhcp.leases`
- **Config**: UCI (`uci show/set/commit`)
- **Default user**: root
- **Default password**: (set during setup, no default)
- **WireGuard**: `opkg install wireguard-tools`
- **AdGuard Home**: manual install or via opkg feed

## GL.iNet (AXT1800, AX1800, MT3000, etc.)

- **SSH**: Dropbear (port 22)
- **Web**: GL.iNet admin panel (port 80/443) + LuCI (port 8080/8443)
- **DHCP leases**: `/tmp/dhcp.leases`
- **Config**: UCI + GL.iNet API (`/rpc` endpoint, JSON-RPC)
- **Default user**: root
- **Special**: Built-in OpenClash, AdGuard Home, WireGuard client/server
- **Note**: GL.iNet admin API only accepts requests from LAN interface, not WG/VPN

## ASUS (Stock / Merlin)

- **SSH**: Dropbear or OpenSSH (enable in admin panel)
- **Web**: ASUSWRT (port 80/443)
- **DHCP leases**: `/var/lib/misc/dnsmasq.leases`
- **Config**: nvram (`nvram get/set/commit`)
- **Default user**: admin
- **WireGuard**: Merlin firmware required

## TP-Link

- **SSH**: Usually disabled by default (enable via web UI or OpenWrt flash)
- **Web**: TP-Link admin (port 80)
- **Default user**: admin
- **Default password**: admin
- **Note**: Stock firmware very limited; recommend OpenWrt flash for full control

## Xiaomi / Redmi

- **SSH**: Disabled by default (requires developer unlock)
- **Web**: MiWiFi (port 80)
- **DHCP leases**: `/tmp/dhcp.leases` (after SSH unlock)
- **Note**: Stock firmware requires app-based setup; SSH unlock process varies by model

## Ubiquiti / UniFi

- **SSH**: OpenSSH (port 22)
- **Web**: UniFi controller
- **Default user**: ubnt
- **Default password**: ubnt
- **DHCP**: Managed by UniFi controller, not local file

## Generic Linux Router

- **SSH**: OpenSSH
- **DHCP leases**: Check dnsmasq or dhcpd config for lease file location
- **Config**: Standard Linux config files
