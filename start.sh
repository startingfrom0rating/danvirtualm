#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$DIR/logs"
PROFILE_DIR="$DIR/profile"
DOWNLOADS_DIR="$DIR/downloads"

mkdir -p "$LOG_DIR"
mkdir -p "$PROFILE_DIR"
mkdir -p "$DOWNLOADS_DIR"

# 0. Automatic Dependency Check — Run setup if critical tools are missing
if ! command -v Xvnc &>/dev/null || ! command -v openbox &>/dev/null || ! command -v node &>/dev/null; then
  echo "⚠️  Missing system dependencies detected. Running setup.sh first..."
  chmod +x "$DIR/setup.sh"
  "$DIR/setup.sh"
fi

# Stop any running instances cleanly first
"$DIR/stop.sh" >/dev/null 2>&1 || true
sleep 1

# Reset runtime URL trackers
: > "$DIR/CURRENT_URL.txt"
: > "$DIR/VM_LINK.txt"

# Source environment variables if .env exists
if [ -f "$DIR/.env" ]; then
  # Read .env ignoring comments and blank lines
  export $(grep -v '^#' "$DIR/.env" | xargs -d '\n')
fi

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
RESOLUTION="${VM_RESOLUTION:-1280x720}"
PASSWORD="${VM_PASSWORD:-ChangeMe123!}"
START_URL="${START_URL:-https://www.google.com}"

# Auto-optimize: enable swap, tune kernel, clean caches
if [ -f "$DIR/optimize_vm.sh" ]; then
  echo "Running pre-launch memory optimization..."
  chmod +x "$DIR/optimize_vm.sh"
  "$DIR/optimize_vm.sh" 2>&1 | sed 's/^/  /' || true

  # Start background memory watchdog
  setsid "$DIR/optimize_vm.sh" --watch < /dev/null > "$LOG_DIR/watchdog.log" 2>&1 &
  echo "🛡️  Memory watchdog started (PID $!)"
fi

echo "=========================================================="
echo " Starting Ultra Low-Latency Virtual Workstation"
echo " Resolution: $RESOLUTION | Display: $DISPLAY_NUM | Port: 6080"
echo "=========================================================="

# Ensure Openbox local config directory has current configs
mkdir -p "$HOME/.config/openbox"
cp -f "$DIR/rc.xml" "$HOME/.config/openbox/rc.xml" 2>/dev/null || true
cp -f "$DIR/menu.xml" "$HOME/.config/openbox/menu.xml" 2>/dev/null || true

# 1. PulseAudio (Audio System)
echo "[1/6] Starting PulseAudio sound server..."
pulseaudio --check 2>/dev/null || pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1 || true

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

# 3. Window Manager (Openbox with full titlebar, dragging & window management)
echo "[3/6] Starting Openbox window manager..."
DISPLAY=$DISPLAY_NUM setsid openbox --config-file "$DIR/rc.xml" < /dev/null > "$LOG_DIR/openbox.log" 2>&1 &
sleep 1

# 4. Tint2 Desktop Taskbar & App Switcher
echo "[4/6] Starting Tint2 desktop taskbar..."
DISPLAY=$DISPLAY_NUM setsid tint2 -c "$DIR/tint2rc" < /dev/null > "$LOG_DIR/tint2.log" 2>&1 &

# 5. Clipboard Synchronization
echo "[5/6] Starting clipboard sync..."
DISPLAY=$DISPLAY_NUM setsid autocutsel -fork < /dev/null > /dev/null 2>&1 || true

# 6. Audio Streamer (Live MP3 HTTP stream on port 6081)
echo "[6/6] Starting live audio engine..."
setsid python3 "$DIR/audio_server.py" < /dev/null > "$LOG_DIR/audio.log" 2>&1 &

# 7. Google Chrome (SwiftShader WebGL, Low-Latency & Stealth)
echo "Launching Google Chrome (Low-Latency & Stealth)..."
rm -f "$PROFILE_DIR"/Singleton*
DISPLAY=$DISPLAY_NUM setsid google-chrome-stable \
  --user-data-dir="$PROFILE_DIR" \
  --disk-cache-dir="/tmp/chrome-cache" \
  --disk-cache-size=134217728 \
  --media-cache-size=67108864 \
  --disable-dev-shm-usage \
  --disable-blink-features=AutomationControlled \
  --use-gl=angle \
  --use-angle=swiftshader \
  --enable-webgl \
  --enable-unsafe-swiftshader \
  --num-raster-threads=2 \
  --enable-zero-copy \
  --disable-gpu-compositing \
  --disable-smooth-scrolling \
  --disable-default-apps \
  --disable-features=OptimizationGuideModelDownloading,OptimizationHints,PassageEmbeddingsService,Translate,MediaRouter,BackgroundSync,SidePanelCompanionDefaultPinned,ReadAnything,AutofillAI,TabGroupsAutoCreate,ComponentUpdatesOnDemand,TabHoverCardImages,WebGPU,HeavyAdIntervention,CalculateNativeWinOcclusion,WinRetrieveSuggestionsOnlyOnDemand \
  --disable-component-update \
  --disable-background-networking \
  --disable-sync \
  --disable-breakpad \
  --disable-domain-reliability \
  --disable-client-side-phishing-detection \
  --no-pings \
  --disable-hang-monitor \
  --disable-ipc-flooding-protection \
  --lang=en-US,en \
  --start-maximized \
  --no-first-run \
  --no-default-browser-check \
  --password-store=basic \
  --remote-debugging-port=9222 \
  "$START_URL" < /dev/null > "$LOG_DIR/chrome.log" 2>&1 &

# 8. Unified Protected Gateway (Multiplexed on ports 3000, 6080, 8080)
echo "Starting unified protected gateway..."
node "$DIR/gateway.js" < /dev/null > "$LOG_DIR/gateway.log" 2>&1 &
GATEWAY_PID=$!

# Wait for Gateway to bind port 3000
for i in {1..15}; do
  if nc -z 127.0.0.1 3000 2>/dev/null || curl -s http://127.0.0.1:3000/ >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

# 9. Direct Cloudflare Tunnel
echo "Starting direct high-speed Cloudflare Tunnel..."
rm -f "$LOG_DIR/cloudflared.log"
setsid cloudflared tunnel --url http://127.0.0.1:3000 < /dev/null > "$LOG_DIR/cloudflared.log" 2>&1 &

# Wait up to 30 seconds for the public tunnel URL to appear
echo -n "Acquiring public Cloudflare Tunnel URL"
TUNNEL_URL=""
for i in {1..30}; do
  sleep 1
  echo -n "."
  TUNNEL_URL=$(grep -o "https://[a-zA-Z0-9-]*\.trycloudflare\.com" "$LOG_DIR/cloudflared.log" 2>/dev/null | tail -n 1 || true)
  if [ -n "$TUNNEL_URL" ]; then
    echo " Done!"
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
  echo "$TUNNEL_URL" > "$DIR/VM_LINK.txt"
  echo "Password: $PASSWORD" >> "$DIR/VM_LINK.txt"
  echo ""
  echo "  👉 PUBLIC STREAM LINK:"
  echo "  $TUNNEL_URL"
  echo "  Password: $PASSWORD"
  echo ""
  echo "  (Saved to CURRENT_URL.txt and VM_LINK.txt for quick access)"
else
  echo ""
  echo "  ⚠️  Cloudflare Quick Tunnel timed out or is running offline."
  echo "  You can access the workstation locally at: http://localhost:6080"
  echo "  Password: $PASSWORD"
fi
echo "=========================================================="

# 10. Tune OOM scores — protect VM infrastructure, deprioritize Chrome renderers
echo "Tuning OOM killer priorities..."
for pid in $(pgrep Xvnc 2>/dev/null); do sudo sh -c "echo -800 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep -f gateway.js 2>/dev/null); do sudo sh -c "echo -800 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep cloudflared 2>/dev/null); do sudo sh -c "echo -800 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep openbox 2>/dev/null); do sudo sh -c "echo -500 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep tint2 2>/dev/null); do sudo sh -c "echo -500 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep autocutsel 2>/dev/null); do sudo sh -c "echo -500 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done

# Chrome renderers are deprioritized compared to system processes
sleep 2
for pid in $(pgrep -f 'chrome.*--type=renderer' 2>/dev/null); do sudo sh -c "echo 300 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep -f 'chrome.*--type=utility' 2>/dev/null); do sudo sh -c "echo 200 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
echo "  ✅ Infrastructure protected, Chrome renderers managed"

# Keep script running while gateway process is alive
wait $GATEWAY_PID
