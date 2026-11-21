#!/bin/bash
set -e

echo "[+] Starting vsftpd (anonymous read-only)..."
mkdir -p /var/run/vsftpd/empty
/usr/sbin/vsftpd /etc/vsftpd.conf &

echo "[+] Starting GlobalCorp portal on port 80..."
exec python3 -u /opt/app/app.py
