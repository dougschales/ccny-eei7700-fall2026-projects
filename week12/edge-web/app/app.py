#!/usr/bin/env python3
"""
GlobalCorp public site - deliberately vulnerable Flask app.

Vulnerabilities (Week 12 capstone, edge-web leg):
  - /login            : classic SQL injection auth bypass (string-built query
                         against an in-process sqlite3 db)
  - /docs?file=        : LFI via naive os.path.join path traversal
"""
import os
import sqlite3

from flask import Flask, request, redirect, url_for, render_template_string, abort

app = Flask(__name__)

DB_PATH = "/opt/app/site.db"
DOCS_DIR = "/opt/app/docs"

LOGIN_PAGE = """
<!doctype html><html><head><title>GlobalCorp Portal</title></head><body>
<h1>GlobalCorp Employee Portal</h1>
{% if error %}<p style="color:red">{{ error }}</p>{% endif %}
<form method="post" action="/login">
  Username: <input name="username"><br>
  Password: <input name="password" type="password"><br>
  <input type="submit" value="Log in">
</form>
<p><a href="/docs?file=changelog.txt">Release notes</a></p>
</body></html>
"""

ADMIN_PAGE = """
<!doctype html><html><head><title>Admin Panel</title></head><body>
<h1>GlobalCorp Admin Panel</h1>
<p>Logged in as: {{ username }}</p>
<h2>CI Integration Settings</h2>
<table border="1" cellpadding="6">
<tr><th>Service</th><td>build-ci Ops API</td></tr>
<tr><th>Auth header</th><td><code>X-Ops-Token</code></td></tr>
<tr><th>Token</th><td><code>{{ token }}</code></td></tr>
</table>
<p>Rotate this token quarterly per policy OPS-220. Do not commit it to any
repo.</p>
<p>FLAG{{ '{' }}w12_2_sqli_auth_bypass_admin_panel{{ '}' }}</p>
</body></html>
"""


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.execute("CREATE TABLE IF NOT EXISTS users (username TEXT, password TEXT)")
    cur = conn.execute("SELECT COUNT(*) FROM users")
    if cur.fetchone()[0] == 0:
        conn.execute(
            "INSERT INTO users (username, password) VALUES (?, ?)",
            ("admin", "C0rp_Portal_Pr0d_2026!"),
        )
        conn.execute(
            "INSERT INTO users (username, password) VALUES (?, ?)",
            ("helpdesk", "Helpdesk2026"),
        )
    conn.commit()
    conn.close()


@app.route("/")
def index():
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return render_template_string(LOGIN_PAGE, error=None)

    username = request.form.get("username", "")
    password = request.form.get("password", "")

    # VULNERABLE: raw string-built SQL query, classic auth-bypass SQLi.
    # e.g. username = admin' OR '1'='1' --  with any password.
    query = "SELECT username FROM users WHERE username = '%s' AND password = '%s'" % (
        username,
        password,
    )
    conn = get_db()
    try:
        cur = conn.execute(query)
        row = cur.fetchone()
    except sqlite3.Error:
        conn.close()
        return render_template_string(LOGIN_PAGE, error="Query error."), 400
    conn.close()

    if row is None:
        return render_template_string(LOGIN_PAGE, error="Invalid credentials."), 401

    return render_template_string(
        ADMIN_PAGE,
        username=row["username"],
        token="cibot_live_7f3a9c2e1d6b4f08",
    )


@app.route("/docs")
def docs():
    # VULNERABLE: naive join, no normalization/allowlist - classic LFI.
    fname = request.args.get("file", "changelog.txt")
    path = os.path.join(DOCS_DIR, fname)
    try:
        with open(path, "r") as f:
            content = f.read()
    except (IOError, OSError):
        abort(404)
    return "<pre>" + content.replace("&", "&amp;").replace("<", "&lt;") + "</pre>"


if __name__ == "__main__":
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    init_db()
    app.run(host="0.0.0.0", port=80)
