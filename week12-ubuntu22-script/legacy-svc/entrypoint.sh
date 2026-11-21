#!/bin/bash
set -e

PROVISION_MARK=/opt/.week12_legacysvc_provisioned

if [ -f "$PROVISION_MARK" ]; then
    echo "[+] Already provisioned - restarting service only."
    exec su - ftpsvc -c "exec python3 -u /opt/app.py"
fi

echo "[+] Initializing Week 12 legacy-svc target..."

# Reused credential from Week 7's lesson: this box still shares one root
# password across every account - exactly what internal-db's credentials
# table (FLAG7) leaked.
echo "root:LegacyRoot26!" | chpasswd

useradd -m -s /bin/bash ftpsvc
mkdir -p /home/ftpsvc/.ftp-cache
cat > /home/ftpsvc/.ftp-cache/handoff.note <<'EOF'
Service account for the legacy FTP listener. Do not use interactively.

FLAG{w12_8_vsftpd_234_backdoor_foothold}
EOF
chown -R ftpsvc:ftpsvc /home/ftpsvc
chmod 700 /home/ftpsvc/.ftp-cache
chmod 600 /home/ftpsvc/.ftp-cache/handoff.note

mkdir -p /root/ops
cat > /root/ops/core-finance-notes.txt <<'EOF'
Core finance DB access notes
=============================
This host also has a leg onto the core-finance network segment
(172.42.2.0/24) for the nightly ledger sync job.

core-finance (172.42.2.40:3306)
  service account: svc_ledger / L3dger_Sync_26!  (database: finance_core)

FLAG{w12_9_legacy_svc_root_credential_reuse}
EOF
chmod 700 /root/ops
chmod 600 /root/ops/core-finance-notes.txt

touch "$PROVISION_MARK"

exec su - ftpsvc -c "exec python3 -u /opt/app.py"
