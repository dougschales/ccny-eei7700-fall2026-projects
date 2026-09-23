#!/usr/bin/env python3
"""
CyberCorp Internal Portal - deliberately vulnerable Flask application.

Vulnerabilities (Week 4: Web Application Exploitation - Part I):
  - /login    : classic SQL injection authentication bypass
  - /backup/* : sensitive file disclosure via robots.txt / misconfiguration
  - /comments : stored XSS, harvested by a real headless-browser admin bot
  - /ping     : OS command injection in a "network diagnostics" tool
"""
import os
import sqlite3
import subprocess
from flask import (
    Flask, request, redirect, url_for, session,
    render_template_string, send_from_directory, Response
)

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET", "dev-secret-change-me")

DB_PATH = "/opt/app/data/app.db"
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "K3ep_This_S3cr3t_9f2a")

FLAG1 = "flag{w4_1_sqli_auth_byp4ss_cl4ss1c}"
# FLAG2 lives in /opt/app/backup/ (disclosed file), FLAG3 is set as a cookie
# by admin_bot.py, and FLAG4 lives in /opt/app/flag4.txt (see entrypoint.sh).


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = get_db()
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE,
            password TEXT,
            role TEXT
        );
        CREATE TABLE IF NOT EXISTS comments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            author TEXT,
            body TEXT
        );
        """
    )
    conn.execute(
        "INSERT OR IGNORE INTO users (id, username, password, role) VALUES (1, 'admin', ?, 'admin')",
        (ADMIN_PASSWORD,),
    )
    conn.execute(
        "INSERT OR IGNORE INTO users (id, username, password, role) VALUES (2, 'jsmith', 'Summer2026!', 'user')"
    )
    conn.execute(
        "INSERT OR IGNORE INTO comments (id, author, body) VALUES "
        "(1, 'jsmith', 'Great new portal, thanks IT!'), "
        "(2, 'admin', 'Reminder: report any bugs here, I review this page daily.')"
    )
    conn.commit()
    conn.close()


BASE_HTML = """
<!DOCTYPE html>
<html>
<head><title>CyberCorp Internal Portal</title></head>
<body style="font-family: sans-serif; max-width: 700px; margin: 40px auto;">
  <h1>CyberCorp Internal Portal</h1>
  <nav>
    <a href="/">Home</a> |
    <a href="/login">Login</a> |
    <a href="/comments">Comments</a> |
    <a href="/ping">Diagnostics</a>
  </nav>
  <hr>
  {{ content|safe }}
</body>
</html>
"""

INDEX_CONTENT = """
<p>Welcome to the CyberCorp employee portal.</p>
<p>Staff: please use the <a href="/login">login</a> page. Report issues via <a href="/comments">Comments</a>.
Network team: the <a href="/ping">Diagnostics</a> tool is available for connectivity checks.</p>
"""

LOGIN_HTML = """
<h2>Staff Login</h2>
{% if error %}<p style="color:red;">{{ error }}</p>{% endif %}
<form method="POST">
  Username: <input type="text" name="username"><br><br>
  Password: <input type="password" name="password"><br><br>
  <input type="submit" value="Login">
</form>
"""

DASH_HTML = """
<h2>Welcome, {{ user }}</h2>
{% if flag %}
<p style="color:green;">Administrator dashboard unlocked.</p>
<p><b>Flag:</b> {{ flag }}</p>
{% else %}
<p>You are logged in as a standard user. Nothing to see here.</p>
{% endif %}
<p><a href="/logout">Logout</a></p>
"""

COMMENTS_HTML = """
<h2>Public Comments / Bug Reports</h2>
<p><i>Reports are reviewed by an administrator.</i></p>
<form method="POST">
  Name: <input type="text" name="author"><br><br>
  Comment: <br><textarea name="body" rows="4" cols="50"></textarea><br><br>
  <input type="submit" value="Submit">
</form>
<hr>
{% for c in comments %}
  <p><b>{{ c['author'] }}</b>: {{ c['body']|safe }}</p>
{% endfor %}
"""

PING_HTML = """
<h2>Network Diagnostics</h2>
<p>Enter a hostname or IP to check connectivity from the server.</p>
<form method="POST">
  Host: <input type="text" name="host" value="127.0.0.1"><br><br>
  <input type="submit" value="Ping">
</form>
{% if output %}
<pre style="background:#eee; padding:10px;">{{ output }}</pre>
{% endif %}
"""


@app.route("/")
def index():
    return render_template_string(BASE_HTML, content=INDEX_CONTENT)


@app.route("/robots.txt")
def robots():
    return Response("User-agent: *\nDisallow: /backup/\n", mimetype="text/plain")


@app.route("/backup/<path:filename>")
def backup(filename):
    return send_from_directory("/opt/app/backup", filename)


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        u = request.form.get("username", "")
        p = request.form.get("password", "")
        conn = get_db()
        # VULNERABLE: string-built SQL query, classic auth-bypass target.
        query = "SELECT * FROM users WHERE username='%s' AND password='%s'" % (u, p)
        try:
            row = conn.execute(query).fetchone()
        except sqlite3.Error:
            row = None
            error = "Database error."
        conn.close()
        if row:
            session["user"] = row["username"]
            session["role"] = row["role"]
            return redirect(url_for("dashboard"))
        elif error is None:
            error = "Invalid credentials."
    return render_template_string(BASE_HTML, content=render_template_string(LOGIN_HTML, error=error))


@app.route("/dashboard")
def dashboard():
    if "user" not in session:
        return redirect(url_for("login"))
    flag = FLAG1 if session.get("role") == "admin" else None
    content = render_template_string(DASH_HTML, user=session["user"], flag=flag)
    return render_template_string(BASE_HTML, content=content)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("index"))


@app.route("/comments", methods=["GET", "POST"])
def comments():
    conn = get_db()
    if request.method == "POST":
        author = request.form.get("author", "anon") or "anon"
        body = request.form.get("body", "")
        # VULNERABLE: comment body rendered unescaped (|safe) -> stored XSS.
        conn.execute("INSERT INTO comments (author, body) VALUES (?, ?)", (author, body))
        conn.commit()
    rows = conn.execute("SELECT * FROM comments ORDER BY id DESC").fetchall()
    conn.close()
    content = render_template_string(COMMENTS_HTML, comments=rows)
    return render_template_string(BASE_HTML, content=content)


@app.route("/ping", methods=["GET", "POST"])
def ping():
    output = None
    if request.method == "POST":
        host = request.form.get("host", "127.0.0.1")
        # VULNERABLE: unsanitized shell=True command construction.
        cmd = "ping -c 1 -W 2 " + host
        try:
            output = subprocess.check_output(
                cmd, shell=True, stderr=subprocess.STDOUT, timeout=15
            ).decode(errors="replace")
        except subprocess.CalledProcessError as e:
            output = e.output.decode(errors="replace") if e.output else str(e)
        except Exception as e:
            output = str(e)
    content = render_template_string(PING_HTML, output=output)
    return render_template_string(BASE_HTML, content=content)


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=80)
