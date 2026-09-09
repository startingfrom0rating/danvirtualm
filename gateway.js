const http = require('http');
const net = require('net');
const url = require('url');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');

// Load environment variables if .env exists
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...vals] = trimmed.split('=');
      if (key && vals.length > 0) {
        process.env[key.trim()] = vals.join('=').trim();
      }
    }
  });
}

const WEB_DIR = path.join(__dirname, 'web');
const VNC_SOCKET = '/tmp/vnc.sock';
const AUDIO_PORT = parseInt(process.env.AUDIO_PORT || '6081', 10);
const PORTS_TO_LISTEN = (process.env.VM_PORTS || '3000,6080,8080')
  .split(',')
  .map(p => parseInt(p.trim(), 10))
  .filter(p => !isNaN(p));

const PASSWORD = process.env.VM_PASSWORD || 'ChangeMe123!';
const AUTH_TOKEN = crypto.createHash('sha256').update(PASSWORD + '_vm_salt_9981').digest('hex');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.map': 'application/json'
};

function renderLoginPage(errorMessage = '') {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Virtual Workstation — Authentication Required</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #0f1117;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 20px;
    }
    .card {
      background: #1a1f2c;
      border: 1px solid #2d3748;
      border-radius: 12px;
      padding: 36px 32px;
      width: 100%;
      max-width: 400px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.5);
      text-align: center;
    }
    .icon {
      font-size: 44px;
      margin-bottom: 16px;
    }
    h1 {
      font-size: 20px;
      font-weight: 600;
      margin-bottom: 8px;
      color: #fff;
    }
    p {
      color: #94a3b8;
      font-size: 14px;
      margin-bottom: 24px;
      line-height: 1.4;
    }
    .error {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid #ef4444;
      color: #fca5a5;
      padding: 10px;
      border-radius: 6px;
      font-size: 13px;
      margin-bottom: 18px;
    }
    input[type="password"] {
      width: 100%;
      padding: 12px 14px;
      background: #0d1117;
      border: 1px solid #3b4252;
      border-radius: 8px;
      color: #fff;
      font-size: 15px;
      outline: none;
      margin-bottom: 18px;
      transition: border-color 0.2s;
    }
    input[type="password"]:focus {
      border-color: #3b82f6;
    }
    button {
      width: 100%;
      padding: 12px;
      background: #2563eb;
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 15px;
      font-weight: 500;
      cursor: pointer;
      transition: background 0.2s;
    }
    button:hover {
      background: #1d4ed8;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">🔒</div>
    <h1>Virtual Workstation</h1>
    <p>This workstation is protected. Enter your password to unlock the desktop session.</p>
    ${errorMessage ? \`<div class="error">\${errorMessage}</div>\` : ''}
    <form method="POST" action="/login">
      <input type="password" name="password" placeholder="Enter password" autofocus required />
      <button type="submit">Unlock Workstation</button>
    </form>
  </div>
</body>
</html>`;
}

function isRequestAuthenticated(req) {
  // 1. Check Cookie
  const cookieHeader = req.headers['cookie'] || '';
  const cookies = {};
  cookieHeader.split(';').forEach((c) => {
    const [k, v] = c.trim().split('=');
    if (k && v) cookies[k] = v;
  });
  if (cookies['vm_auth'] === AUTH_TOKEN) {
    return true;
  }

  // 2. Check Authorization header (Basic auth)
  const authHeader = req.headers['authorization'];
  if (authHeader && authHeader.startsWith('Basic ')) {
    try {
      const credentials = Buffer.from(authHeader.split(' ')[1], 'base64').toString('utf8');
      const [, pass] = credentials.split(':');
      if (pass === PASSWORD) {
        return true;
      }
    } catch (_) {}
  }

  // 3. Check query param ?auth=...
  const parsed = url.parse(req.url, true);
  if (parsed.query && (parsed.query.auth === PASSWORD || parsed.query.auth === AUTH_TOKEN)) {
    return true;
  }

  return false;
}

function serveStaticFile(req, res, pathname) {
  let relativePath = pathname;
  if (relativePath === '/' || relativePath === '') {
    relativePath = '/index.html';
  }

  // Prevent directory traversal
  const safePath = path.normalize(relativePath).replace(/^(\.\.[\/\\])+/, '');
  const filePath = path.join(WEB_DIR, safePath);

  if (!filePath.startsWith(WEB_DIR)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('File Not Found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, {
      'Content-Type': contentType,
      'Content-Length': stats.size,
      'Cache-Control': 'no-cache'
    });

    const stream = fs.createReadStream(filePath);
    stream.pipe(res);
  });
}

function createServerInstance() {
  const server = http.createServer((req, res) => {
    if (req.socket) {
      req.socket.setNoDelay(true);
    }

    const parsed = url.parse(req.url, true);

    // Handle Login submission
    if (req.method === 'POST' && parsed.pathname === '/login') {
      let body = '';
      req.on('data', chunk => {
        body += chunk;
        if (body.length > 1024) req.destroy();
      });
      req.on('end', () => {
        const params = new URLSearchParams(body);
        const enteredPassword = params.get('password') || '';
        if (enteredPassword === PASSWORD) {
          // Set authentication cookie for 30 days
          res.writeHead(302, {
            'Set-Cookie': `vm_auth=${AUTH_TOKEN}; Path=/; HttpOnly; Max-Age=2592000; SameSite=Lax`,
            'Location': '/'
          });
          res.end();
        } else {
          res.writeHead(401, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(renderLoginPage('Incorrect password. Please try again.'));
        }
      });
      return;
    }

    // Handle Logout
    if (parsed.pathname === '/logout') {
      res.writeHead(302, {
        'Set-Cookie': `vm_auth=; Path=/; HttpOnly; Max-Age=0`,
        'Location': '/'
      });
      res.end();
      return;
    }

    // Check Authentication
    if (!isRequestAuthenticated(req)) {
      res.writeHead(401, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(renderLoginPage());
      return;
    }

    // Handle Authenticated Audio Stream
    if (parsed.pathname === '/audio' || parsed.pathname === '/audio.mp3') {
      const proxyReq = http.request({
        host: '127.0.0.1',
        port: AUDIO_PORT,
        path: '/audio',
        method: req.method,
        headers: { ...req.headers, host: `127.0.0.1:${AUDIO_PORT}` }
      }, (proxyRes) => {
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(res);
      });
      proxyReq.on('error', () => {
        res.writeHead(503, { 'Content-Type': 'text/plain' });
        res.end('Audio stream initializing...');
      });
      req.pipe(proxyReq);
    } else {
      serveStaticFile(req, res, parsed.pathname);
    }
  });

  // Direct native Node.js WebSocket Server connecting to /tmp/vnc.sock
  const wss = new WebSocketServer({
    server,
    verifyClient: (info, callback) => {
      if (isRequestAuthenticated(info.req)) {
        callback(true);
      } else {
        callback(false, 401, 'Unauthorized');
      }
    },
    handleProtocols: (protocols) => {
      if (protocols.has('binary')) return 'binary';
      if (protocols.has('base64')) return 'base64';
      return false;
    }
  });

  wss.on('error', (err) => {
    console.warn('WSS internal error:', err.message);
  });

  wss.on('connection', (ws) => {
    const vncSocket = net.connect(VNC_SOCKET, () => {
      vncSocket.setNoDelay(true);
    });

    ws.on('message', (data) => {
      if (vncSocket.writable) {
        vncSocket.write(data);
      }
    });

    vncSocket.on('data', (chunk) => {
      if (ws.readyState === ws.OPEN) {
        ws.send(chunk, { binary: true });
      }
    });

    const cleanup = () => {
      try { vncSocket.destroy(); } catch (_) {}
      try { ws.close(); } catch (_) {}
    };

    ws.on('close', cleanup);
    ws.on('error', cleanup);
    vncSocket.on('close', cleanup);
    vncSocket.on('error', cleanup);
  });

  return server;
}

PORTS_TO_LISTEN.forEach((port) => {
  try {
    const srv = createServerInstance();
    srv.on('error', (err) => {
      console.warn(`Port ${port} error: ${err.message}`);
    });
    srv.listen(port, '0.0.0.0', () => {
      console.log(`Protected Low-Latency Gateway listening on port ${port}`);
    });
  } catch (e) {
    console.warn(`Error on port ${port}:`, e);
  }
});
