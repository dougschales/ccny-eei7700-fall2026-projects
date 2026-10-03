#!/bin/bash
set -e

echo "[+] Initializing webapp target..."

# Flag 4 - reachable only via code execution on /import (no web route
# serves this file directly).
echo "flag{w5_4_insecure_deser_pickle_rce}" > /opt/app/flag4.txt
chmod 644 /opt/app/flag4.txt

exec python3 /opt/app/app.py
