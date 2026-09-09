#!/usr/bin/env bash
echo "=== Virtual Workstation Status ==="
echo -n "TigerVNC X-Server (Xvnc :1): "
pgrep -fa "Xvnc :1" >/dev/null && echo "Running [OK]" || echo "Stopped [OFF]"

echo -n "Window Manager (Openbox): "
pgrep -fa "openbox" >/dev/null && echo "Running [OK]" || echo "Stopped [OFF]"

echo -n "Taskbar (Tint2): "
pgrep -fa "tint2" >/dev/null && echo "Running [OK]" || echo "Stopped [OFF]"

echo -n "Clipboard Sync (autocutsel): "
pgrep -fa "autocutsel" >/dev/null && echo "Running [OK]" || echo "Stopped [OFF]"

echo -n "Audio Streamer: "
pgrep -fa "audio_server.py" >/dev/null && echo "Running [OK]" || echo "Stopped [OFF]"

echo -n "Unified Gateway: "
pgrep -fa "gateway.js" >/dev/null && echo "Running [OK]" || echo "Stopped [OFF]"

echo -n "Cloudflare Tunnel: "
pgrep -fa "cloudflared" >/dev/null && echo "Running [OK]" || echo "Stopped [OFF]"

echo -n "Google Chrome: "
pgrep -fa "chrome" >/dev/null && echo "Running [OK]" || echo "Stopped [OFF]"
echo "==================================="
