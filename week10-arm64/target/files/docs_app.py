#!/usr/bin/env python3
"""
FleetOps Internal Docs - deliberately vulnerable Flask application.

Vulnerability (reusing the Week 5 bug class): /docs/view takes a "file"
query parameter and os.path.join()s it onto DOCS_DIR with no sanitization,
so "../" traversal (or an absolute path) escapes DOCS_DIR entirely. The
public /docs listing only shows a handful of harmless files; the real
target of this leak is /opt/app/internal/releases/, which is never linked
from any page and holds the exact statusd binary and source running on
this box (see statusd.xinetd) - the point of this bug is simply to get
that binary and source onto the student's own machine for offline
analysis, the same way a real leaked internal file share might.
"""
import os
from flask import Flask, request, render_template_string, Response

app = Flask(__name__)

DOCS_DIR = "/opt/app/docs"

BASE_HTML = """
<!DOCTYPE html>
<html>
<head><title>FleetOps Internal Docs</title></head>
<body style="font-family: sans-serif; max-width: 700px; margin: 40px auto;">
  <h1>FleetOps Internal Docs</h1>
  <nav><a href="/">Home</a> | <a href="/docs">Documents</a></nav>
  <hr>
  {{ content|safe }}
</body>
</html>
"""

INDEX_CONTENT = """
<p>Welcome to the FleetOps internal documentation portal.</p>
<p>Browse <a href="/docs">published documents</a> for the status collector
rollout.</p>
"""

DOCS_HTML = """
<h2>Document Library</h2>
<ul>
{% for name in entries %}
  <li><a href="/docs/view?file={{ name }}">{{ name }}</a></li>
{% endfor %}
</ul>
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
    # VULNERABLE: os.path.join() does not strip "../" traversal, and an
    # absolute path discards DOCS_DIR entirely - either way this is not
    # confined to DOCS_DIR.
    path = os.path.join(DOCS_DIR, filename)
    try:
        with open(path, "rb") as f:
            data = f.read()
    except Exception as e:
        return Response(f"Error: {e}", status=404, mimetype="text/plain")
    return Response(data, mimetype="application/octet-stream")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
