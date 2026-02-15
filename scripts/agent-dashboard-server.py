#!/usr/bin/env python3
"""
agent-dashboard-server.py - Minimal HTTP server for agent dashboard

Serves a single-page HTML dashboard with JSON API endpoints.
Data is sourced from existing scripts called as subprocesses.

Usage:
    python3 agent-dashboard-server.py [--port 8787] [--host 127.0.0.1]

API Endpoints:
    GET /              Dashboard HTML
    GET /api/agents    agent-state.sh --all --json
    GET /api/convoys   convoy.sh list --json
    GET /api/queue     merge-queue.sh list --json
    GET /api/mail      agent-mail.sh inbox --json
    GET /api/mayor     gwt-mayor.sh status --json
    GET /api/molecules molecule.sh list --json
"""

import http.server
import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
DEFAULT_PORT = 8787
DEFAULT_HOST = "127.0.0.1"


def run_script(script_name, *args):
    """Run a script and return its stdout as string."""
    script_path = SCRIPT_DIR / script_name
    if not script_path.exists():
        return json.dumps({"error": f"{script_name} not found"})
    try:
        result = subprocess.run(
            ["bash", str(script_path), *args],
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result.stdout.strip() if result.returncode == 0 else json.dumps({"error": result.stderr.strip()})
    except subprocess.TimeoutExpired:
        return json.dumps({"error": "timeout"})
    except Exception as e:
        return json.dumps({"error": str(e)})


class DashboardHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default logging
        pass

    def send_json(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        if isinstance(data, str):
            self.wfile.write(data.encode())
        else:
            self.wfile.write(json.dumps(data).encode())

    def send_html(self, content):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(content.encode())

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            html_path = SCRIPT_DIR / "agent-dashboard.html"
            if html_path.exists():
                self.send_html(html_path.read_text())
            else:
                self.send_html("<h1>Dashboard HTML not found</h1>")

        elif self.path == "/api/agents":
            self.send_json(run_script("agent-state.sh", "--all", "--json"))

        elif self.path == "/api/convoys":
            self.send_json(run_script("convoy.sh", "list", "--json"))

        elif self.path == "/api/queue":
            self.send_json(run_script("merge-queue.sh", "list", "--json"))

        elif self.path == "/api/mail":
            self.send_json(run_script("agent-mail.sh", "inbox", "--json"))

        elif self.path == "/api/mayor":
            self.send_json(run_script("gwt-mayor.sh", "status", "--json"))

        elif self.path == "/api/molecules":
            self.send_json(run_script("molecule.sh", "list", "--json"))

        else:
            self.send_response(404)
            self.end_headers()


def main():
    port = DEFAULT_PORT
    host = DEFAULT_HOST

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--port" and i + 1 < len(args):
            port = int(args[i + 1])
            i += 2
        elif args[i] == "--host" and i + 1 < len(args):
            host = args[i + 1]
            i += 2
        elif args[i] in ("--help", "-h"):
            print(f"Usage: {sys.argv[0]} [--port {DEFAULT_PORT}] [--host {DEFAULT_HOST}]")
            sys.exit(0)
        else:
            i += 1

    server = http.server.HTTPServer((host, port), DashboardHandler)
    print(f"Dashboard server running at http://{host}:{port}")
    print(f"Press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")
        server.server_close()


if __name__ == "__main__":
    main()
