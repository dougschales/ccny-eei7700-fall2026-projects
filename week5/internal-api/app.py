#!/usr/bin/env python3
"""
Internal Reporting API - not reachable from the internet or from the
student workstation directly. Only webapp has network access to this
host (see docker-compose.yml and entrypoint.sh, which firewalls this
container's own network namespace).

Week 5: Web Application Exploitation - Part II
  - Reaching this service via webapp's /fetch SSRF bug is the target.
"""
import os

from flask import Flask, request, jsonify

app = Flask(__name__)
API_TOKEN = os.environ.get("API_TOKEN", "changeme")
FLAG3 = "flag{w5_3_ssrf_internal_api_pivot}"


@app.route("/")
def index():
    return jsonify({
        "service": "internal-reporting-api",
        "note": "internal use only - not internet-facing",
        "endpoints": {"/status": "service health + status (requires service token)"},
    })


@app.route("/status")
def status():
    auth = request.headers.get("Authorization", "")
    if auth != f"Bearer {API_TOKEN}":
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({"status": "ok", "flag": FLAG3})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
