#!/bin/bash
set -e

echo "[+] Initializing Week 11 pivot target..."

# --- Low-privileged foothold account (credentials leak via the web
# server's own docroot - see Dockerfile's ops-archive backup) --------
if ! id "webadmin" &>/dev/null; then
    useradd -m -s /bin/bash webadmin
    echo "webadmin:N0v2026_Maint!" | chpasswd
fi

mkdir -p /home/webadmin/.cache
cat > /home/webadmin/.cache/session-handoff.note <<'EOF'
Temp account handoff note - leave this account alone until the
migration window officially closes.

FLAG{w11_1_leaked_backup_ssh_foothold}
EOF
chown -R webadmin:webadmin /home/webadmin
chmod 700 /home/webadmin/.cache
chmod 600 /home/webadmin/.cache/session-handoff.note

# --- sshd ---------------------------------------------------------------
install -m 644 /opt/build/sshd_config.d_lab.conf /etc/ssh/sshd_config.d/lab.conf
mkdir -p /var/run/sshd
/usr/sbin/sshd
echo "[+] Started SSH server on port 22 (AllowTcpForwarding no)"

# --- cron: nightly healthcheck against the internal db, hardcoded ------
# creds and all - this is how a student finds svc_monitor's password.
install -m 644 /opt/build/db-healthcheck-cron /etc/cron.d/db-healthcheck
service cron start
echo "[+] Started cron daemon"

# --- nginx (edge-facing portal + the ops-archive leak) ------------------
nginx
echo "[+] Started nginx on port 80"

echo "[+] pivot ready: edge_net 172.41.0.10, internal_net 172.41.1.10"
exec tail -f /dev/null
