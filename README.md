# danvirtualm - Cloud Virtual Workstation & Browser Streamer

A standalone, ultra low-latency cloud-streamed Linux virtual desktop running Google Chrome, XFCE desktop utilities, live PulseAudio streaming, clipboard sync, and password authentication.

## Features
- **Stealth Anti-Bot Chrome:** Disables automation flags (`navigator.webdriver = false`), includes SwiftShader WebGL canvas rendering, and realistic browser headers.
- **Persistent Profile & Cookies:** Browser sessions, logins, extensions, and bookmarks are saved in `./profile/`.
- **Live Sound Streaming:** Built-in PulseAudio engine streaming live MP3 audio to the browser with one-click sound toggle and volume slider.
- **Desktop Taskbar & Utilities:** Includes `tint2` taskbar with clock, window switcher, `xfce4-terminal`, `thunar` file manager, and `mousepad` text editor.
- **Bidirectional Clipboard Sync:** Automatic two-way clipboard synchronization between your physical machine and the virtual desktop.
- **Password Protection:** Built-in session authentication gate with cookie session persistence.
- **Unified Single Port Gateway:** Serves web UI, WebSocket RFB display stream, and real-time audio through a single multiplexed Node.js gateway.
- **Direct Cloudflare Tunnel:** Generates a secure, zero-config HTTPS public link via `cloudflared` to access the machine from any device.

---

## Prerequisites & Installation

On Debian / Ubuntu / GitHub Codespaces:

```bash
# 1. Clone repository
git clone https://github.com/startingfrom0rating/danvirtualm.git
cd danvirtualm

# 2. Run system setup script
chmod +x setup.sh start.sh status.sh stop.sh
./setup.sh
```

---

## Configuration

Copy the example configuration file:

```bash
cp .env.example .env
```

Edit `.env` to set your desired password and resolution:

```env
VM_PASSWORD=MySecretPassword123!
VM_RESOLUTION=1280x720
```

---

## Quick Start

1. **Start the Virtual Machine:**
   ```bash
   ./start.sh
   # or with npm:
   npm start
   ```

2. **Access the Stream:**
   - **Local / Codespace Port Forwarding:** Open port `3000` or `6080` in your browser.
   - **Public Tunnel Link:** If Cloudflare Tunnel is available, `start.sh` prints a public `https://*.trycloudflare.com` link and writes it to `CURRENT_URL.txt`.

3. **Check Running Status:**
   ```bash
   ./status.sh
   ```

4. **Stop the Session:**
   ```bash
   ./stop.sh
   ```

---

## Repository Structure

```
├── .env.example        # Environment variable template
├── .gitignore          # Excludes logs, cache, downloads, and user profiles
├── audio_server.py     # PulseAudio to MP3 live HTTP streaming daemon
├── gateway.js          # Unified HTTP, WebSocket & password auth server
├── package.json        # Node.js runner scripts & dependencies
├── rc.xml              # Openbox window manager configuration
├── setup.sh            # One-click dependency installer for Ubuntu/Debian
├── start.sh            # Main orchestration startup script
├── status.sh           # Service status inspection script
├── stop.sh             # Graceful teardown script
├── tint2rc             # Desktop panel & taskbar configuration
└── web/                # HTML5 noVNC client & integrated live audio player
```
