fu#!/usr/bin/env python3
"""
Simple HTTP Live Audio Streamer from PulseAudio.
Serves real-time MP3 audio stream from the default PulseAudio monitor.
"""

import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import sys
import os

PORT = int(os.environ.get("AUDIO_PORT", 6081))

class AudioStreamHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Quiet logs

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-Type", "audio/mpeg")
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/audio"):
            self.send_response(200)
            self.send_header("Content-Type", "audio/mpeg")
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Connection", "close")
            self.end_headers()

            # Start ffmpeg capture from pulseaudio
            cmd = [
                "ffmpeg",
                "-hide_banner",
                "-loglevel", "error",
                "-f", "pulse",
                "-i", "default",
                "-c:a", "libmp3lame",
                "-b:a", "128k",
                "-ar", "44100",
                "-ac", "2",
                "-f", "mp3",
                "-"
            ]
            
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=4096)
            try:
                while True:
                    chunk = proc.stdout.read(4096)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    proc.kill()
        else:
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Audio Stream Server Ready. Connect to /audio")

def run():
    server = HTTPServer(("0.0.0.0", PORT), AudioStreamHandler)
    print(f"Audio server listening on port {PORT}...")
    server.serve_forever()

if __name__ == "__main__":
    run()
