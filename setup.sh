#!/usr/bin/env bash
set -e

echo "=== Installing Virtual Machine System Dependencies ==="

sudo apt-get update -y
sudo apt-get install -y \
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
  ca-certificates

# Install Google Chrome if not already present
if ! command -v google-chrome-stable &> /dev/null; then
  echo "Installing Google Chrome..."
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
  sudo apt-get install -y /tmp/chrome.deb
  rm -f /tmp/chrome.deb
fi

# Install cloudflared if not already present
if ! command -v cloudflared &> /dev/null; then
  echo "Installing Cloudflare Tunnel (cloudflared)..."
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
  sudo apt-get update -y && sudo apt-get install -y cloudflared || {
    echo "Fallback: Downloading binary directly..."
    curl -L --output /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    sudo install -m 755 /tmp/cloudflared /usr/local/bin/cloudflared
    rm -f /tmp/cloudflared
  }
fi

# Install Node dependencies
if command -v npm &> /dev/null; then
  echo "Installing Node.js dependencies..."
  npm install
fi

echo "=== Setup complete! ==="
echo "You can configure your password in .env (or run ./start.sh directly)."
