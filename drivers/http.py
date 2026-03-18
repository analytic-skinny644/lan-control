"""
HTTP protocol driver — executes commands on devices via HTTP API.
Used for: E-ink displays, cameras, smart home devices with REST APIs.
"""
import json
import subprocess
import shutil
from urllib.request import urlopen, Request
from urllib.error import URLError


def execute(device_config: dict, command_name: str, cmd_spec: dict, params: list) -> dict:
    """Execute an HTTP command on the device."""
    ip = device_config.get("ip", "")
    if not ip:
        return {"ok": False, "error": "No target IP. Run 'devices' to discover devices first."}

    conn = device_config.get("connection", {})
    port = conn.get("port", 80)
    method_default = conn.get("method", "http")

    action = cmd_spec.get("action", "")
    if not action:
        return {"ok": False, "error": f"Command '{command_name}' has no action defined"}

    # Parse action: "GET /status" or "POST /display"
    parts = action.split(None, 1)
    if len(parts) == 2:
        http_method, path = parts[0].upper(), parts[1]
    elif action.startswith("/"):
        http_method, path = "GET", action
    else:
        return {"ok": False, "error": f"Cannot parse HTTP action: {action}"}

    scheme = "https" if port == 443 else "http"
    url = f"{scheme}://{ip}:{port}{path}"

    # Build request body from params
    body = None
    if params and http_method in ("POST", "PUT", "PATCH"):
        # If single param, send as-is; multiple params, JSON-encode
        if len(params) == 1:
            body = params[0].encode("utf-8")
        else:
            cmd_params = cmd_spec.get("params", [])
            payload = dict(zip(cmd_params, params)) if cmd_params else {"data": params}
            body = json.dumps(payload).encode("utf-8")

    try:
        req = Request(url, data=body, method=http_method)
        req.add_header("User-Agent", "lan-control/1.0")
        if body:
            req.add_header("Content-Type", "application/json")

        with urlopen(req, timeout=10) as resp:
            output = resp.read().decode("utf-8", errors="replace")
            return {"ok": True, "output": output[:4096], "status": resp.status}

    except URLError as e:
        return {"ok": False, "error": f"HTTP request failed: {e.reason}"}
    except Exception as e:
        return {"ok": False, "error": str(e)}
