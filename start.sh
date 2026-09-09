#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$DIR/logs"
PROFILE_DIR="$DIR/profile"
DOWNLOADS_DIR="$DIR/downloads"

mkdir -p "$LOG_DIR"
mkdir -p "$PROFILE_DIR"
mkdir -p "$DOWNLOADS_DIR"

# Source environment variables if .env exists
if [ -f "$DIR/.env" ]; then
  export $(grep -v '^#' "$DIR/.env" | xargs -d '\n')
fi

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
RESOLUTION="${VM_RESOLUTION:-1280x720}"
PASSWORD="${VM_PASSWORD:-ChangeMe123!}"

# Stop any running instances cleanly
"$DIR/stop.sh" >/dev/null 2>&1 || true
sleep 1

echo "=========================================================="
echo " Starting Ultra Low-Latency Virtual Workstation"
echo " Resolution: $RESOLUTION | Display: $DISPLAY_NUM"
echo "=========================================================="

# 1. PulseAudio (Audio System)
echo "[1/6] Starting PulseAudio sound server..."
pulseaudio --check || pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1 || true

# 2. TigerVNC High-Performance X Server (Zero-Copy, Instant Flush, 30 FPS, CompareFB 2)
echo "[2/6] Starting TigerVNC X-Server (Zero-Latency Pipeline)..."
rm -f /tmp/vnc.sock
setsid Xvnc $DISPLAY_NUM \
  -geometry $RESOLUTION \
  -depth 24 \
  -SecurityTypes None \
  -rfbport -1 \
  -rfbunixpath /tmp/vnc.sock \
  -rfbunixmode 0666 \
  -ac \
  -pn \
  -dpi 96 \
  -fakescreenfps 30 \
  -FrameRate 30 \
  -CompareFB 2 \
  -AlwaysShared \
  < /dev/null > "$LOG_DIR/xvnc.log" 2>&1 &
sleep 1

# 3. Window Manager (Openbox - Native Popup & Dropdown Support)
echo "[3/6] Starting Openbox window manager..."
DISPLAY=$DISPLAY_NUM setsid openbox --config-file "$DIR/rc.xml" < /dev/null > "$LOG_DIR/openbox.log" 2>&1 &
sleep 1

# 4. Tint2 Desktop Taskbar & App Switcher
echo "[4/6] Starting Tint2 desktop taskbar..."
DISPLAY=$DISPLAY_NUM setsid tint2 -c "$DIR/tint2rc" < /dev/null > "$LOG_DIR/tint2.log" 2>&1 &

# 5. Clipboard Synchronization (Clipboard buffer only to preserve popup focus)
echo "[5/6] Starting clipboard sync..."
DISPLAY=$DISPLAY_NUM setsid autocutsel -fork < /dev/null > /dev/null 2>&1 || true

# 6. Audio Streamer (MP3 HTTP stream on port 6081)
echo "[6/6] Starting live audio engine..."
setsid python3 "$DIR/audio_server.py" < /dev/null > "$LOG_DIR/audio.log" 2>&1 &

# 7. Google Chrome (WebGL via SwiftShader, Stable Memory, Stealth)
echo "Launching Google Chrome (Low-Latency & Stealth)..."
rm -f "$PROFILE_DIR"/Singleton*
DISPLAY=$DISPLAY_NUM setsid google-chrome-stable \
  --user-data-dir="$PROFILE_DIR" \
  --disk-cache-dir="/tmp/chrome-cache" \
  --disable-dev-shm-usage \
  --disable-blink-features=AutomationControlled \
  --use-gl=angle \
  --use-angle=swiftshader \
  --enable-webgl \
  --disable-gpu-compositing \
  --disable-smooth-scrolling \
  --renderer-process-limit=4 \
  --disable-default-apps \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-ipc-flooding-protection \
  --lang=en-US,en \
  --start-maximized \
  --no-first-run \
  --no-default-browser-check \
  --password-store=basic \
  https://www.google.com < /dev/null > "$LOG_DIR/chrome.log" 2>&1 &

# 8. Direct High-Speed Cloudflare Tunnel
echo "Starting direct high-speed Cloudflare Tunnel..."
rm -f "$LOG_DIR/cloudflared.log"
setsid cloudflared tunnel --url http://127.0.0.1:3000 < /dev/null > "$LOG_DIR/cloudflared.log" 2>&1 &

# Wait up to 10 seconds for the public tunnel URL to appear
TUNNEL_URL=""
for i in {1..10}; do
  sleep 1
  TUNNEL_URL=$(grep -o "https://[a-zA-Z0-9-]*\.trycloudflare\.com" "$LOG_DIR/cloudflared.log" 2>/dev/null | head -n 1 || true)
  if [ -n "$TUNNEL_URL" ]; then
    break
  fi
done

echo ""
echo "=========================================================="
echo "  Ultra Low-Latency Virtual Workstation is RUNNING!"
echo "  Local Ports: 3000, 6080, 8080"
if [ -n "$TUNNEL_URL" ]; then
  echo "$TUNNEL_URL" > "$DIR/CURRENT_URL.txt"
  echo "Password: $PASSWORD" >> "$DIR/CURRENT_URL.txt"
  echo ""
  echo "  👉 PUBLIC STREAM LINK:"
  echo "  $TUNNEL_URL"
  echo "  Password: $PASSWORD"
  echo ""
  echo "  (Saved to CURRENT_URL.txt)"
fi
echo "=========================================================="

# Run Native Low-Latency Gateway in foreground to keep server active
exec node "$DIR/gateway.js"
