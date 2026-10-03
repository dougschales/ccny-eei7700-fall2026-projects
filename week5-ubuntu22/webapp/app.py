#!/usr/bin/env python3
"""
CyberCorp Reporting Portal v2 - deliberately vulnerable Flask application.

Vulnerabilities (Week 5: Web Application Exploitation - Part II):
  - /docs/view  : Local File Inclusion via unsanitized path join (also
                  discloses config/settings.py, which leaks the
                  internal-api token used by the /fetch bug below)
  - /fetch      : Server-Side Request Forgery - fetches an arbitrary,
                  user-supplied URL and blindly attaches this app's own
                  internal service credentials to the outbound request
  - /import     : Insecure deserialization - unpickles attacker-controlled
                  data, which can execute arbitrary code during load
"""
import base64
import os
import pickle
import sys

import requests
from flask import (
    Flask, request, render_template_string, Response
)

sys.path.insert(0, "/opt/app/config")
import settings  # noqa: E402  (see /opt/app/config/settings.py)

app = Flask(__name__)

DOCS_DIR = "/opt/app/docs"
DEFAULT_SETTINGS = {"theme": "light", "font_size": 14}

FLAG1_HINT = "See /opt/app/notes/ (not linked from the docs listing)."
# FLAG2 lives inside config/settings.py itself (also LFI-reachable).
# FLAG3 is served by internal-api's /status route, gated on the
# Authorization token that lives in config/settings.py.
# FLAG4 lives at /opt/app/flag4.txt - no route serves it; it requires
# code execution via the /import bug (see entrypoint.sh).
# FLAG5 lives in internal-db, reachable only from webapp's network
# position, using credentials in config/db_config.py (not linked from
# any route - only discoverable after getting a shell).


BASE_HTML = """
<!DOCTYPE html>
<html>
<head><title>CyberCorp Reporting Portal</title></head>
<body style="font-family: sans-serif; max-width: 700px; margin: 40px auto;">
  <h1>CyberCorp Reporting Portal</h1>
  <nav>
    <a href="/">Home</a> |
    <a href="/docs">Documents</a> |
    <a href="/fetch">Fetch Report</a> |
    <a href="/import">Import Settings</a>
  </nav>
  <hr>
  {{ content|safe }}
</body>
</html>
"""

INDEX_CONTENT = """
<p>Welcome to the CyberCorp Reporting Portal (v2).</p>
<p>Browse published <a href="/docs">documents</a>, pull in an externally
hosted <a href="/fetch">report</a>, or <a href="/import">restore a saved
settings export</a> from another environment.</p>
"""

DOCS_HTML = """
<h2>Document Library</h2>
<ul>
{% for name in entries %}
  <li><a href="/docs/view?file={{ name }}">{{ name }}</a></li>
{% endfor %}
</ul>
"""

FETCH_HTML = """
<h2>Fetch Report from URL</h2>
<p>Enter the URL of a published report and we'll pull its contents in for
your dashboard.</p>
<form method="POST">
  URL: <input type="text" name="url" size="50" value="{{ url or '' }}"><br><br>
  <input type="submit" value="Fetch">
</form>
{% if error %}<p style="color:red;">Error: {{ error }}</p>{% endif %}
{% if output %}
<pre style="background:#eee; padding:10px; white-space:pre-wrap;">{{ output }}</pre>
{% endif %}
"""

IMPORT_HTML = """
<h2>Import Settings Backup</h2>
<p>Paste a settings export (from <a href="/export">Export Settings</a>) to
restore your report theme and preferences.</p>
<form method="POST">
  Export blob:<br>
  <textarea name="data" rows="4" cols="60"></textarea><br><br>
  <input type="submit" value="Import">
</form>
{% if error %}<p style="color:red;">Error: {{ error }}</p>{% endif %}
{% if result %}
<p><b>Imported:</b> {{ result }}</p>
{% endif %}
"""


@app.route("/")
def index():
    return render_template_string(BASE_HTML, content=INDEX_CONTENT)


@app.route("/docs")
def docs_index():
    entries = sorted(os.listdir(DOCS_DIR))
    content = render_template_string(DOCS_HTML, entries=entries)
    return render_template_string(BASE_HTML, content=content)


@app.route("/docs/view")
def docs_view():
    filename = request.args.get("file", "")
    # VULNERABLE: os.path.join() does not sanitize "../" traversal, and if
    # `filename` starts with "/" it discards DOCS_DIR entirely and returns
    # the absolute path unchanged. Either way, an attacker isn't confined
    # to DOCS_DIR.
    path = os.path.join(DOCS_DIR, filename)
    try:
        with open(path, "r", errors="replace") as f:
            data = f.read()
    except Exception as e:
        return Response(f"Error: {e}", status=404, mimetype="text/plain")
    return Response(data, mimetype="text/plain")


@app.route("/export")
def export_settings():
    # Legitimate half of the import/export feature: produces a base64'd
    # pickle of the current settings, meant to be pasted back in via /import
    # on another environment.
    blob = base64.b64encode(pickle.dumps(DEFAULT_SETTINGS)).decode()
    return Response(blob, mimetype="text/plain")


@app.route("/import", methods=["GET", "POST"])
def import_settings():
    result = None
    error = None
    if request.method == "POST":
        data = request.form.get("data", "")
        try:
            raw = base64.b64decode(data)
            # VULNERABLE: pickle.loads() on attacker-controlled bytes can
            # execute arbitrary code via __reduce__ during deserialization -
            # this doesn't require the result to be used at all.
            obj = pickle.loads(raw)
            result = repr(obj)
        except Exception as e:
            error = str(e)
    content = render_template_string(IMPORT_HTML, result=result, error=error)
    return render_template_string(BASE_HTML, content=content)


@app.route("/fetch", methods=["GET", "POST"])
def fetch():
    output = None
    error = None
    target_url = None
    if request.method == "POST":
        target_url = request.form.get("url", "")
        headers = {"Authorization": f"Bearer {settings.INTERNAL_API_TOKEN}"}
        try:
            # VULNERABLE: no allow-list on scheme/host, so `target_url` can
            # point anywhere the server can reach - including internal-api,
            # which is not reachable from the student workstation directly.
            # The internal auth header is attached to every outbound
            # request regardless of destination, which is exactly what
            # makes this SSRF dangerous: it reuses webapp's own trust.
            resp = requests.get(target_url, headers=headers, timeout=5)
            output = resp.text
        except Exception as e:
            error = str(e)
    content = render_template_string(
        FETCH_HTML, output=output, error=error, url=target_url
    )
    return render_template_string(BASE_HTML, content=content)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
