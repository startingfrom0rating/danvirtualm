# danvirtualm — Ultra Low-Latency Cloud Virtual Workstation & Browser

A lightweight, high-performance Linux virtual workstation and anti-bot browser streamed directly to any web browser over HTTPS with ultra-low latency, live audio streaming, and seamless clipboard synchronization.

![Virtual Workstation](https://raw.githubusercontent.com/novnc/noVNC/master/app/images/icons/novnc-192x192.png)

## Features

- **🚀 Ultra Low-Latency Video Pipeline:** Powered by TigerVNC (`Xvnc`) with native backpressure flow control, instant buffer drainage, and client-side quality preset switching (Balanced, Low Bandwidth, High Quality).
- **🛡️ Stealth Anti-Bot Google Chrome:** Preconfigured with hardware-free SwiftShader WebGL, disabled automation flags (`navigator.webdriver = false`), stealth canvas rendering, and zero V8 heap crashes.
- **🔊 Real-Time Live Audio:** PulseAudio monitor pipeline streaming real-time MP3 audio directly to your browser via an integrated web audio player with volume control.
- **🪟 Complete Window Management:** Openbox window manager with full mouse support (titlebar dragging, double-click to maximize, border/corner resizing, Alt+drag, and desktop right-click menu).
- **📋 Bidirectional Clipboard Sync:** Seamless two-way copy-pasting between your host machine and the virtual desktop.
- **🌐 Zero-Config Cloudflare Tunnel:** Generates a secure HTTPS link via `cloudflared` so you can connect from any device, tablet, or phone without port forwarding.
- **🔐 Password Protection:** Built-in authentication gate with session cookies and SHA-256 validation.
- **🧹 Memory Watchdog & OOM Shield:** Automatically enables swap space, optimizes kernel parameters, cleans cache bloat, and runs a proactive background watchdog to prevent out-of-memory lockups.

---

## ⚡ Quick Start

### 1. Clone & Start (Automatic Setup)

On any Debian/Ubuntu system, Docker container, or **GitHub Codespace**:

```bash
git clone https://github.com/startingfrom0rating/danvirtualm.git
cd danvirtualm

# Make scripts executable and start (dependencies will auto-install if missing)
chmod +x *.sh
./start.sh
```

### 2. Access the Virtual Machine

When the startup finishes, `start.sh` displays your connection details:

```text
==========================================================
  Ultra Low-Latency Virtual Workstation is RUNNING!
  Local Ports: 3000, 6080, 8080

  👉 PUBLIC STREAM LINK:
  https://xxxx-xxxx-xxxx.trycloudflare.com
  Password: ChangeMe123!

  (Saved to CURRENT_URL.txt and VM_LINK.txt for quick access)
==========================================================
```

- **Cloudflare Link:** Open the generated HTTPS URL on any device.
- **Local / Port Forwarding:** Open `http://localhost:6080` (or port `3000` / `8080`).
- Enter your password to unlock the desktop session.

---

## ⚙️ Configuration (Optional)

Copy `.env.example` to `.env` to customize your workstation settings:

```bash
cp .env.example .env
```

| Variable | Default | Description |
|---|---|---|
| `VM_PASSWORD` | `ChangeMe123!` | Password required to unlock the web session |
| `VM_RESOLUTION` | `1280x720` | Desktop screen resolution (e.g. `1920x1080`, `1280x720`) |
| `DISPLAY_NUM` | `:1` | X11 virtual display number |
| `START_URL` | `https://www.google.com` | Initial page opened in Chrome on launch |
| `VM_PORTS` | `3000,6080,8080` | Local ports listened on by the unified gateway |
| `AUDIO_PORT` | `6081` | Internal port for the PulseAudio MP3 stream |

---

## 🛠️ Management Commands

| Task | Command | Description |
|---|---|---|
| **Install Dependencies** | `./setup.sh` (or `npm run setup`) | Installs Chrome, TigerVNC, Openbox, and cloudflared |
| **Start Workstation** | `./start.sh` (or `npm start`) | Launches all services and establishes public tunnel |
| **Check Status** | `./status.sh` (or `npm run status`) | Inspects health of all 8 workstation daemons |
| **Stop Workstation** | `./stop.sh` (or `npm run stop`) | Gracefully shuts down services and clears temporary sockets |
| **Memory Optimization** | `./optimize_vm.sh` | Cleans caches, tunes kernel sysctl, and verifies swap |

---

## 📁 Repository Structure

```text
├── .env.example        # Environment variable template
├── .gitignore          # Ignores runtime tokens, caches, and user profiles
├── audio_server.py     # PulseAudio to MP3 live HTTP streaming daemon
├── gateway.js          # Unified HTTP, WebSocket & password auth server with flow control
├── menu.xml            # Openbox desktop right-click menu
├── optimize_vm.sh      # Memory optimization engine and watchdog
├── package.json        # Node.js runner scripts & dependencies
├── rc.xml              # Openbox window manager configuration (drag, resize, shortcuts)
├── setup.sh            # Zero-friction system dependency installer
├── start.sh            # Main orchestration startup script
├── status.sh           # Service status inspection script
├── stop.sh             # Graceful teardown script
├── tint2rc             # Desktop panel & taskbar configuration
└── web/                # HTML5 noVNC client & integrated live audio player
```

---

## 📄 License

MIT
