"""
ADB protocol driver — executes commands on Android devices via ADB over WiFi.
Used for: Android TV boxes, tablets, phones with ADB enabled.
"""
import subprocess
import shutil


def _ensure_connected(ip: str, port: int = 5555) -> bool:
    """Ensure ADB is connected to the device."""
    if not shutil.which("adb"):
        return False

    target = f"{ip}:{port}"
    # Check if already connected
    result = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=10)
    if target in result.stdout:
        return True

    # Try to connect
    result = subprocess.run(["adb", "connect", target], capture_output=True, text=True, timeout=10)
    return "connected" in result.stdout.lower()


def execute(device_config: dict, command_name: str, cmd_spec: dict, params: list) -> dict:
    """Execute an ADB command on the device."""
    if not shutil.which("adb"):
        return {"ok": False, "error": "adb not found. Install Android SDK platform-tools: https://developer.android.com/tools/releases/platform-tools"}

    ip = device_config.get("ip", "")
    if not ip:
        return {"ok": False, "error": "No target IP. Run 'devices' to discover devices first."}

    conn = device_config.get("connection", {})
    port = conn.get("port", 5555)

    if not _ensure_connected(ip, port):
        return {"ok": False, "error": f"Cannot connect to {ip}:{port}. Enable ADB over WiFi in device Settings → Developer Options."}

    target = f"{ip}:{port}"
    action = cmd_spec.get("action", "")
    if not action:
        return {"ok": False, "error": f"Command '{command_name}' has no action defined"}

    # Substitute params into action string
    if params and "{" in action:
        for i, p in enumerate(params):
            action = action.replace(f"{{{i}}}", p)
        # Also handle named params like {package}
        cmd_params = cmd_spec.get("params", [])
        for name, value in zip(cmd_params, params):
            action = action.replace(f"{{{name}}}", value)
    elif params:
        action = f"{action} {' '.join(params)}"

    # Parse the action into adb command parts
    # Actions look like: "adb shell input keyevent 3" or "adb install foo.apk"
    if action.startswith("adb "):
        adb_args = action[4:].split()
    else:
        # Bare command, wrap in adb shell
        adb_args = ["shell", action]

    cmd = ["adb", "-s", target] + adb_args

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

    if result.returncode == 0:
        return {"ok": True, "output": result.stdout.strip()}
    else:
        return {"ok": False, "error": result.stderr.strip() or f"Exit code {result.returncode}", "output": result.stdout.strip()}
