#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo " Installing Virtual Machine System Dependencies"
echo "=========================================================="

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo &>/dev/null; then
    SUDO="sudo"
  else
    echo "⚠️  Running as non-root without sudo. Some system package installs may fail."
  fi
fi

# 1. Update package lists and install core desktop tools
echo "[1/4] Installing desktop utilities, audio, and VNC server..."
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends \
  tigervnc-standalone-server \
  openbox \
  tint2 \
  autocutsel \
  pulseaudio \
  ffmpeg \
  xfce4-terminal \
  thunar \
  mousepad \
  xdotool \
  curl \
  wget \
  ca-certificates \
  python3

# 2. Install Google Chrome if not already present
echo "[2/4] Checking Google Chrome..."
if ! command -v google-chrome-stable &>/dev/null; then
  echo "Installing Google Chrome Stable..."
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
  $SUDO apt-get install -y /tmp/chrome.deb || $SUDO apt-get install -f -y
  rm -f /tmp/chrome.deb
else
  echo "✅ Google Chrome is already installed."
fi

# 3. Install Cloudflare Tunnel (cloudflared) if not present
echo "[3/4] Checking Cloudflare Tunnel (cloudflared)..."
if ! command -v cloudflared &>/dev/null; then
  echo "Installing cloudflared binary..."
  ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
  case "$ARCH" in
    arm64|aarch64) CF_ARCH="arm64" ;;
    *) CF_ARCH="amd64" ;;
  esac
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o /tmp/cloudflared || \
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o /tmp/cloudflared
  chmod +x /tmp/cloudflared
  $SUDO mv /tmp/cloudflared /usr/local/bin/cloudflared
  echo "✅ cloudflared installed successfully."
else
  echo "✅ cloudflared is already installed."
fi

# 4. Install Node.js dependencies
echo "[4/4] Setting up Node.js dependencies and environment..."
if command -v npm &>/dev/null; then
  cd "$DIR" && npm install --silent
else
  echo "⚠️  npm not found. Please ensure Node.js is installed to run gateway.js."
fi

# Generate default .env from template if not present
if [ ! -f "$DIR/.env" ] && [ -f "$DIR/.env.example" ]; then
  cp "$DIR/.env.example" "$DIR/.env"
  echo "Created default .env configuration."
fi

# Ensure executable permissions on all shell scripts
chmod +x "$DIR"/*.sh 2>/dev/null || true

echo "=========================================================="
echo " ✅ Setup Complete!"
echo " Start your virtual machine with: ./start.sh"
echo " (or configure your password in .env first)"
echo "=========================================================="
