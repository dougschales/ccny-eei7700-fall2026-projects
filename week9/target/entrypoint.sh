#!/bin/bash
set -e

PROVISION_MARK=/opt/.week9_provisioned

# Idempotency guard: this container has restart: unless-stopped, and a
# crashed/rebooted/manually-restarted container re-runs this entrypoint
# against its *same* writable layer, where opskey/the sudoers rule/the
# archived key already exist. Without this guard, useradd fails under
# `set -e` on every restart and the target silently crash-loops. Skip
# straight to restarting services if already provisioned.
if [ -f "$PROVISION_MARK" ]; then
    echo "[+] Already provisioned - restarting services only."
    mkdir -p /var/run/sshd
    /usr/sbin/sshd
    echo "[+] Started SSH server on port 22"
    python3 /opt/app/api_app.py &
    echo "[+] Restarted HelpDesk API on port 8080"
    wait -n
fi

echo "[+] Initializing Week 9 API security target..."

# --- Service account reachable only via a key leaked through the API ----
# Unlike previous weeks, there is no password handed out and no direct
# SSH foothold account. The only way onto this box is to find and
# decrypt this key through the HelpDesk API itself.
useradd -m -s /bin/bash opskey
passwd -l opskey >/dev/null   # no password login - key-only account
mkdir -p /home/opskey/.ssh
ssh-keygen -t rsa -b 2048 -f /tmp/opskey_key -N "Opskey24" -C opskey -q
cp /tmp/opskey_key.pub /home/opskey/.ssh/authorized_keys
chmod 700 /home/opskey/.ssh
chmod 600 /home/opskey/.ssh/authorized_keys
chown -R opskey:opskey /home/opskey/.ssh

# The archived private key, served up as a ticket attachment by the API -
# only reachable once a caller has escalated to the admin role.
mkdir -p /opt/app/data/attachments
cp /tmp/opskey_key /opt/app/data/attachments/vpn_key_rotation.pem
chmod 644 /opt/app/data/attachments/vpn_key_rotation.pem
rm -f /tmp/opskey_key /tmp/opskey_key.pub

echo "FLAG{service_account_key_cracked_ssh_foothold}" > /home/opskey/key_cracked_flag.txt
chmod 600 /home/opskey/key_cracked_flag.txt
chown opskey:opskey /home/opskey/key_cracked_flag.txt

# --- Final vector: passwordless sudo on a different GTFOBins binary -----
# A new vector from Week 7's four (SUID PATH hijack / sudo find /
# cap_setuid python3 / world-writable cron) - same category of bug
# (sudo misconfiguration), different specific binary.
install -m 440 /opt/build/opskey-sudoers /etc/sudoers.d/opskey
mkdir -p /root/release-audit
cat > /root/release-audit/tar_sudo_note.log <<'EOF'
Release packaging - tar invoked via sudo for opskey, review pending
FLAG{sudo_nopasswd_tar_gtfobins}
EOF
chmod 700 /root/release-audit
chmod 600 /root/release-audit/tar_sudo_note.log

echo "FLAG{root_api_chain_complete}" > /root/chain_complete.txt
chmod 600 /root/chain_complete.txt

touch "$PROVISION_MARK"

# --- sshd ------------------------------------------------------------
install -m 644 /opt/build/sshd_config.d_lab.conf /etc/ssh/sshd_config.d/lab.conf
mkdir -p /var/run/sshd
/usr/sbin/sshd
echo "[+] Started SSH server on port 22"

# --- HelpDesk API ------------------------------------------------------
python3 /opt/app/api_app.py &
echo "[+] HelpDesk API started on port 8080"

echo "[+] Target ready."
wait -n
