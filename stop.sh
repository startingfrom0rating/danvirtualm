#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Stopping all virtual workstation services gracefully..."
SERVICES=("cloudflared" "gateway.js" "audio_server.py" "websockify" "autocutsel" "tint2" "openbox" "fluxbox" "Xvnc :1" "Xvfb :1" "x11vnc" "chrome" "optimize_vm.sh")

# Send SIGTERM first for graceful cleanup
for svc in "${SERVICES[@]}"; do
  pkill -15 -f "$svc" 2>/dev/null || true
done

# Wait briefly for processes to exit cleanly
sleep 1

# Force kill any stubborn lingering processes
for svc in "${SERVICES[@]}"; do
  pkill -9 -f "$svc" 2>/dev/null || true
done

rm -f /tmp/vnc.sock
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
rm -f "$DIR/CURRENT_URL.txt" "$DIR/VM_LINK.txt"
echo "All virtual workstation services stopped."
