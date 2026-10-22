#!/usr/bin/env python3
"""
Simple HTTP Live Audio Streamer from PulseAudio.
Serves real-time MP3 audio stream from the default PulseAudio monitor.
"""
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
import sys
import os

PORT = int(os.environ.get("AUDIO_PORT", 6081))
CHUNK_SIZE = 1024  # 1024 bytes at 128kbps is ~64ms buffer (reduced from 4096 / ~256ms)

class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

class AudioStreamHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silence standard HTTP access logging to keep logs clean
        pass

    def do_GET(self):
        if self.path == '/audio' or self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'audio/mpeg')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()

            # Record from PulseAudio default monitor and transcode directly to MP3 stream via ffmpeg
            cmd = [
                "ffmpeg",
                "-f", "pulse",
                "-i", "default",
                "-c:a", "libmp3lame",
                "-b:a", "128k",
                "-ar", "44100",
                "-ac", "2",
                "-f", "mp3",
                "-flush_packets", "1",
                "-"
            ]
            
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=CHUNK_SIZE)
            try:
                while True:
                    chunk = proc.stdout.read(CHUNK_SIZE)
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
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"Audio Stream Server Ready. Connect to /audio")

def run():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), AudioStreamHandler)
    print(f"Audio server listening on port {PORT}...")
    server.serve_forever()

if __name__ == '__main__':
    run()
