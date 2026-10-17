#!/bin/bash
set -e

echo "[+] Initializing Week 7 privilege-escalation target..."

# --- Low-privileged foothold account -----------------------------------
if ! id "trainee" &>/dev/null; then
    useradd -m -s /bin/bash trainee
    echo "trainee:Summer2026!" | chpasswd
fi
mkdir -p /home/trainee/scratch
echo "FLAG{low_priv_ssh_foothold}" > /home/trainee/user_flag.txt
chmod 644 /home/trainee/user_flag.txt
chown -R trainee:trainee /home/trainee

# --- Vector 1: SUID binary with an unqualified PATH lookup --------------
gcc -o /usr/local/bin/diag /opt/build/diag.c
chown root:root /usr/local/bin/diag
chmod 4755 /usr/local/bin/diag
# diag's own report archive - a plausible place for a root-owned
# diagnostics tool to keep its past output.
mkdir -p /root/diag-reports
cat > /root/diag-reports/latest_snapshot.log <<'EOF'
[diag] process snapshot archived 03:14
FLAG{suid_path_hijack_diag_binary}
EOF
chmod 700 /root/diag-reports
chmod 600 /root/diag-reports/latest_snapshot.log

# --- Vector 2: passwordless sudo on a GTFOBins-listed binary -------------
install -m 440 /opt/build/trainee-sudoers /etc/sudoers.d/trainee

# the "nightly audit script" the sudoers comment refers to - its report.
mkdir -p /root/audit
cat > /root/audit/stale_files_report.txt <<'EOF'
Nightly stale-file audit
FLAG{sudo_nopasswd_find_gtfobins}
EOF
chmod 700 /root/audit
chmod 600 /root/audit/stale_files_report.txt

# --- Vector 3: a Linux capability handed to an interpreter --------------
PY3_BIN=$(readlink -f "$(command -v python3)")
setcap cap_setuid+ep "$PY3_BIN"
# a note left behind from whoever granted the capability on python3.
mkdir -p /root/interpreter-audit
cat > /root/interpreter-audit/python3_cap.log <<'EOF'
cap_setuid+ep granted to python3 interpreter - review pending
FLAG{capability_cap_setuid_python3}
EOF
chmod 700 /root/interpreter-audit
chmod 600 /root/interpreter-audit/python3_cap.log

# --- Vector 4: world-writable script run by root's cron ------------------
mkdir -p /opt/maintenance
install -m 777 /opt/build/cleanup.sh /opt/maintenance/cleanup.sh
install -m 644 /opt/build/maintenance-cron /etc/cron.d/maintenance
# cron's own run log, sitting right next to the script it executes.
cat > /opt/maintenance/.last_run.log <<'EOF'
cleanup.sh last run: root cron, every minute
FLAG{cron_world_writable_root_script}
EOF
chown root:root /opt/maintenance/.last_run.log
chmod 600 /opt/maintenance/.last_run.log

# --- Final flag, readable only once you are root -------------------------
echo "FLAG{root_youve_escalated_linux_privesc_complete}" > /root/privesc_complete.txt
chmod 600 /root/privesc_complete.txt

# --- sshd ------------------------------------------------------------
install -m 644 /opt/build/sshd_config.d_lab.conf /etc/ssh/sshd_config.d/lab.conf
mkdir -p /var/run/sshd
/usr/sbin/sshd
echo "[+] Started SSH server on port 22"

# --- cron ------------------------------------------------------------
service cron start
echo "[+] Started cron daemon"

echo "[+] Target ready."
exec tail -f /dev/null
