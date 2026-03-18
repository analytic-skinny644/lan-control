# Troubleshooting

Real-world issues encountered and solved during development.

## Fake IP Trap (198.18.0.0/16) ⚠️ Most Common

**Symptom**: SSH connects but you get the wrong device (e.g., your own Mac instead of the router). SSH banner shows `SSH-2.0-OpenSSH_10.0` instead of `SSH-2.0-dropbear`.

**Cause**: VPN clients (Clash, Surge, Shadowrocket, V2Ray) create TUN interfaces with fake-ip ranges. The most common: `198.18.0.0/16` (Clash fake-ip DNS mode). Your system's default gateway may point to this TUN IP.

**Diagnosis**:
```bash
# Check what your gateway really is
route -n get default          # macOS
ip route show default         # Linux

# If gateway is 198.18.x.x — that's Clash, not your router
echo "" | nc -w 2 198.18.0.1 22
# Shows "SSH-2.0-OpenSSH" = your own machine, NOT the router
```

**Solution**: `discover.sh` auto-detects fake IPs and falls back to scanning common subnets (192.168.1.1, 192.168.0.1, etc.). Manual fix: check your actual LAN interface IP — your router is at `x.x.x.1`.

## ISP Port Blocking (WireGuard)

**Symptom**: WireGuard handshake never completes. `wg show` shows `transfer: X received, 0 sent` (or vice versa). Packets go out but replies never arrive.

**Cause**: Some ISPs block UDP port 51820 (WireGuard default) and 1194 (OpenVPN default).

**Diagnosis**:
```bash
# On server: listen on the port
nc -u -l 51820

# On client: send test packet
echo "test" | nc -u <server_ip> 51820

# If no response → port is blocked
# Try a different port:
echo "test" | nc -u <server_ip> 51821  # non-standard port
```

**Solution**: Change to a non-standard port:
```bash
# Server side
wg set wg0 listen-port 51821
sed -i 's/ListenPort = 51820/ListenPort = 51821/' /etc/wireguard/wg0.conf

# Client side (OpenWrt UCI)
uci set network.<peer>.endpoint_port=51821
uci commit network
ifdown wg0; sleep 1; ifup wg0
```

## SSH Auth Failures

**Common causes**:

1. **Wrong IP** — See Fake IP section above. Verify with SSH banner.
2. **Dropbear quirks** — OpenWrt uses Dropbear, not OpenSSH. Password prompts differ:
   - OpenSSH: `Password:`
   - Dropbear: `root@192.168.1.1's password:`
   Use `expect` to handle both formats. `sshpass` works but isn't installed on macOS by default.
3. **Key format** — Dropbear uses its own key format. If key auth fails, ensure your key is in OpenSSH format (Dropbear can read it, but older versions may not).
4. **MaxAuthTries** — Dropbear limits to 3 attempts per connection (`-T 3`). Script that tries multiple passwords needs separate SSH connections per attempt.

## Double NAT

**Symptom**: Router's WAN IP is private (192.168.x.x, 10.x.x.x). Port forwarding doesn't work. VPN connections are unreliable.

**Diagnosis**:
```bash
# Check router WAN IP
ssh root@<router> "ip addr show eth0"
# If WAN IP is 192.168.x.x → you're behind double NAT

# Common setup: ISP modem (192.168.2.1) → your router (192.168.8.1)
# Your router's WAN gets 192.168.2.x from ISP modem
```

**Solutions** (in order of preference):
1. **Bridge mode** — Set ISP modem to bridge/passthrough mode
2. **Relay VPN** — Use Tailscale/ZeroTier (punches through NAT)
3. **TCP tunnels** — SSH reverse tunnel or frp (more reliable through symmetric NAT than UDP-based VPN)

## Router Memory Pressure (OOM)

**Symptom**: Services crash randomly. Tailscale goes offline. SSH drops mid-session. `dmesg` shows OOM killer messages.

**Cause**: Home routers have 256-512MB RAM. Running Clash + Tailscale + AdGuard Home can exhaust memory.

**Diagnosis**:
```bash
ssh root@<router> "free -m"
# If 'available' < 20MB, you're in danger zone
```

**Solutions**:
1. **Enable swap** on external storage (USB/SD card):
   ```bash
   dd if=/dev/zero of=/path/to/swapfile bs=1M count=512
   chmod 600 /path/to/swapfile
   mkswap /path/to/swapfile
   swapon /path/to/swapfile
   # Add to /etc/rc.local for persistence
   ```
2. **Reduce Clash memory** — Lower `profile.store-fake-ip` cache size
3. **Disable unused services** — Tailscale is a memory hog (~30-50MB)
4. **Monitor continuously** — Set up a cron job: `free -m | awk '/Mem:/{if($7<20) system("logger -t OOM_WARN low_memory")}'`

## GL.iNet Admin API Access Denied

**Symptom**: `curl http://192.168.1.1/rpc` returns "Access denied" when called from VPN/WireGuard tunnel.

**Cause**: GL.iNet's admin API (`/rpc`, `/cgi-bin/api.cgi`) is restricted to requests from the LAN bridge interface (`br-lan`). Traffic from WireGuard or VPN interfaces is rejected.

**Solution**: Use SSH commands instead of the HTTP API when connecting remotely. All `uci` commands work fine over SSH regardless of source interface.

## AdGuard Home Filter Rules Won't Download

**Symptom**: AGH filter lists show 0 rules. Update button gives timeout errors.

**Cause**: If router uses VPN/proxy, AGH's DNS requests may be routed through the VPN, creating a circular dependency. Or GitHub/filter list URLs are blocked.

**Solutions**:
1. **Manual import**: Download filter lists on another machine, SCP to router:
   ```bash
   # On a machine with internet access
   curl -o adguard.txt https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
   scp adguard.txt root@<router>:/etc/AdGuardHome/data/
   ```
2. **Use file:// URLs** in AGH config: `url: file:///etc/AdGuardHome/data/adguard.txt`
3. **Bypass VPN for AGH**: Add AGH binary to VPN bypass list in OpenClash settings
