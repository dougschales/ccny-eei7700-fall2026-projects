#!/bin/bash
set -e

echo "[+] Initializing webapp target..."

# Flag 4 - reachable only via command injection on /ping (no direct web route).
echo "flag{w4_4_p1ng_cmd_1nj3ct10n_rce}" > /opt/app/flag4.txt
chmod 644 /opt/app/flag4.txt

python3 /opt/app/app.py &
echo "[+] Flask app started on port 80"

# Give Flask a moment to come up before the bot starts hitting it.
sleep 3
python3 /opt/app/admin_bot.py &
echo "[+] Admin bot started"

wait -n
