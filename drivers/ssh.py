"""
SSH protocol driver — executes commands on devices via SSH.
Used for: routers (OpenWrt), Linux SBCs, any SSH-accessible device.
"""
import json
import subprocess
from pathlib import Path

STATE_FILE = Path.home() / ".lan-control" / "state.json"


def _get_target_ip(device_config: dict) -> str:
    """Resolve target IP. For routers, use router_ip from state."""
    if device_config.get("type") == "router":
        if STATE_FILE.exists():
            with open(STATE_FILE) as f:
                state = json.load(f)
            return state.get("router_ip", "")
    # For non-router SSH devices, IP must be passed via device_config
    return device_config.get("ip", "")


def execute(device_config: dict, command_name: str, cmd_spec: dict, params: list) -> dict:
    """Execute an SSH command on the device."""
    ip = _get_target_ip(device_config)
    if not ip:
        return {"ok": False, "error": "No target IP. Run 'discover' and 'devices' first."}

    conn = device_config.get("connection", {})
    port = conn.get("port", 22)
    user = "root"

    action = cmd_spec.get("action", "")
    if not action:
        return {"ok": False, "error": f"Command '{command_name}' has no action defined"}

    # Substitute params into action string
    if params and "{" in action:
        for i, p in enumerate(params):
            action = action.replace(f"{{{i}}}", p)
    elif params:
        action = f"{action} {' '.join(params)}"

    cmd = [
        "ssh",
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=10",
        "-p", str(port),
        f"{user}@{ip}",
        action,
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

    if result.returncode == 0:
        return {"ok": True, "output": result.stdout.strip()}
    else:
        return {"ok": False, "error": result.stderr.strip() or f"Exit code {result.returncode}", "output": result.stdout.strip()}
