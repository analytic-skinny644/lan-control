# Device YAML Schema Reference

Complete specification for device configuration files in `devices/<type>/<name>.yaml`.

## Structure

```yaml
device:         # Required — Device metadata
discovery:      # Required — How to auto-detect this device
connection:     # Optional — How to connect (defaults inferred from protocol)
commands:       # Required — Available control commands
```

## device (required)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Human-readable name |
| `type` | string | ✅ | Category: `router`, `tv`, `ir-remote`, `speaker`, `camera`, `ac`, `iot` |
| `vendor` | string | ✅ | Manufacturer name |
| `protocol` | string | ✅ | Control protocol: `ssh`, `http`, `websocket`, `ssap`, `mqtt`, `ir-bridge`, `adb` |

## discovery (required)

At least one discovery method must be provided. Multiple methods = higher match confidence.

| Field | Type | Description |
|-------|------|-------------|
| `mac_prefixes` | string[] | MAC address prefixes (e.g., `"4c:ba:d7"`) |
| `hostname_patterns` | string[] | Regex patterns for DHCP hostname |
| `mdns_services` | string[] | mDNS/Bonjour service names |
| `ssdp_search` | string[] | SSDP/UPnP search targets |
| `ports` | int[] | TCP ports the device typically opens |

### MAC Prefix Format
Use lowercase, colon-separated, first 3 octets: `"4c:ba:d7"`

### Hostname Patterns
Python regex. Use `(?i)` for case-insensitive: `"(?i)LGwebOS"`

## connection (optional)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `method` | string | (from protocol) | `ssh`, `http`, `websocket`, `mqtt`, `ir-bridge`, `adb` |
| `port` | int | (protocol default) | Default port |
| `secure` | bool | false | Use SSL/TLS |
| `secure_port` | int | — | Alternative secure port |
| `auth.type` | string | `none` | `none`, `password`, `key`, `pairing`, `token` |
| `auth.description` | string | — | Human-readable auth instructions |

## commands (required)

Each command is a key-value pair:

```yaml
commands:
  command_name:
    description: "What this does"     # Required
    action: "protocol-specific-uri"   # Protocol-specific action
    method: query                     # Optional: query (read-only), wol (special)
    params:                           # Optional: command parameters
      param_name:
        type: int|string|boolean|array
        min: 0                        # For int
        max: 100                      # For int
        enum: [a, b, c]              # For string with fixed choices
        examples: [x, y]             # For string with suggested values
        required: true                # Default: false
        default: value               # Default value
        description: "Explanation"    # Human-readable
```

### Action Formats by Protocol

| Protocol | Action format | Example |
|----------|--------------|---------|
| `ssh` | Shell command | `"free -m"` |
| `http` | `METHOD /path` | `"POST /api/power/off"` |
| `ssap` | SSAP URI | `"ssap://audio/setVolume"` |
| `websocket` | JSON message type | `"set_volume"` |
| `mqtt` | Topic | `"device/command/power"` |
| `ir-bridge` | IR code reference | `"ac_power_on"` |

### Special Methods

- `wol` — Wake-on-LAN (uses device MAC from discovery)
- `query` — Read-only command (no side effects)
