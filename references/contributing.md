# Contributing a New Device

Adding support for a new device takes 5 minutes. You just need to create one YAML file.

## Steps

### 1. Fork & Clone

```bash
git clone https://github.com/<your-fork>/router-control.git
cd router-control
```

### 2. Pick the Right Category

```
devices/
  router/      # Routers (OpenWrt, ASUS, TP-Link, etc.)
  tv/          # Smart TVs (LG, Samsung, Roku, etc.)
  ir-remote/   # IR remotes (BroadLink, Tuya, etc.)
  speaker/     # Smart speakers (Google, Amazon, etc.)
  camera/      # IP cameras (Reolink, Hikvision, etc.)
  ac/          # Air conditioners
  iot/         # Generic IoT (Tasmota, Tuya, ESP, etc.)
```

New category? Create a new folder. No code changes needed — the registry auto-scans all subdirectories.

### 3. Create Your YAML File

Copy the schema template:

```bash
cp devices/_schema.yaml devices/tv/my-new-tv.yaml
```

Fill in the three sections:

#### Device Info
```yaml
device:
  name: "My Smart TV"
  type: tv
  vendor: MyBrand
  protocol: http      # ssh/http/websocket/mqtt/ir-bridge/adb
```

#### Discovery (how to auto-detect this device)
```yaml
discovery:
  mac_prefixes:       # First 3 bytes of MAC address
    - "aa:bb:cc"      # Find yours: check router DHCP leases
  hostname_patterns:  # Regex patterns for DHCP hostname
    - "(?i)mysmartv"
  ports:              # Ports the device typically opens
    - 8080
```

**Finding MAC prefixes:** Check your router's DHCP lease table, or search [macaddress.io](https://macaddress.io) for your device's vendor.

#### Commands (what this device can do)
```yaml
commands:
  power_off:
    description: "关机"
    action: "POST /api/power/off"
  
  volume_up:
    description: "音量+"
    action: "POST /api/volume/up"
  
  set_volume:
    description: "设置音量"
    action: "POST /api/volume/set"
    params:
      level:
        type: int
        min: 0
        max: 100
```

### 4. Test Locally

```bash
# Verify YAML loads correctly
python3 registry.py

# Check your device shows up
python3 cli.py supported
```

### 5. Submit PR

```bash
git add devices/tv/my-new-tv.yaml
git commit -m "Add support for MyBrand Smart TV"
git push origin main
# Open PR on GitHub
```

## Tips

- **Not sure about the exact API?** Add commands you've verified and mark uncertain ones with `# TODO: verify`
- **Multiple models share the same protocol?** Put them in one YAML with all MAC prefixes listed
- **Device uses a proprietary protocol?** Document what you know — even partial support helps
- **IR-controlled devices** (AC, fan, etc.) go through an IR bridge like BroadLink. Put the device under its own category (e.g., `ac/`) and note the bridge requirement

## YAML Validation

The full schema reference is at `references/device-schema.md`. Required fields:

- `device.name` — Human-readable name
- `device.type` — Category (must match folder name)
- `device.vendor` — Manufacturer
- `discovery` — At least one discovery method (mac_prefixes or hostname_patterns)
- `commands` — At least one command
