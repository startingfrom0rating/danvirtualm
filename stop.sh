#!/usr/bin/env bash
echo "Stopping all virtual workstation services..."
pkill -9 -f "cloudflared" || true
pkill -9 -f "gateway.js" || true
pkill -9 -f "audio_server.py" || true
pkill -9 -f "websockify" || true
pkill -9 -f "autocutsel" || true
pkill -9 -f "tint2" || true
pkill -9 -f "openbox" || true
pkill -9 -f "fluxbox" || true
pkill -9 -f "Xvnc :1" || true
pkill -9 -f "Xvfb :1" || true
pkill -9 -f "x11vnc" || true
pkill -9 -f "chrome" || true
rm -f /tmp/vnc.sock
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
echo "All virtual workstation services stopped."
