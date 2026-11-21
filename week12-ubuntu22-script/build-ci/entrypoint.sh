#!/bin/bash
set -e

PROVISION_MARK=/opt/.week12_buildci_provisioned

start_services() {
    mkdir -p /var/run/sshd
    /usr/sbin/sshd
    echo "[+] sshd started on port 22"
    exec python3 -u /opt/app/api_app.py
}

if [ -f "$PROVISION_MARK" ]; then
    echo "[+] Already provisioned - restarting services only."
    start_services
fi

echo "[+] Initializing Week 12 build-ci target..."

# --- ci-runner: key-only service account, no password login -----------
useradd -m -s /bin/bash ci-runner
passwd -l ci-runner >/dev/null

mkdir -p /home/ci-runner/.ssh /opt/app/data/artifacts
ssh-keygen -t rsa -b 2048 -f /tmp/ci_runner_key -N "StageSeven_Deploy26" -C ci-runner -q
cp /tmp/ci_runner_key.pub /home/ci-runner/.ssh/authorized_keys
chmod 700 /home/ci-runner/.ssh
chmod 600 /home/ci-runner/.ssh/authorized_keys
chown -R ci-runner:ci-runner /home/ci-runner/.ssh

# Archived outgoing deploy key, served by the API once a caller has
# escalated to admin via mass assignment (see api_app.py).
cp /tmp/ci_runner_key /opt/app/data/artifacts/ci_runner_deploy_key.pem.enc
chmod 644 /opt/app/data/artifacts/ci_runner_deploy_key.pem.enc
rm -f /tmp/ci_runner_key /tmp/ci_runner_key.pub

mkdir -p /home/ci-runner/.build-history
cat > /home/ci-runner/.build-history/last-deploy.log <<'EOF'
[deploy] stage-7741 build #4412 shipped clean
FLAG{w12_5_ssh_key_passphrase_cracked_foothold}
EOF
chmod 600 /home/ci-runner/.build-history/last-deploy.log
chown -R ci-runner:ci-runner /home/ci-runner/.build-history

# --- Sudo misconfiguration: unrestricted tar (GTFOBins) ------------------
install -m 440 /opt/build/ci-runner-sudoers /etc/sudoers.d/ci-runner

# --- Root-side evidence of the pivot + internal-db creds ----------------
mkdir -p /root/ops
install -m 600 /opt/build/network-notes.txt /root/ops/network-notes.txt
chmod 700 /root/ops

# --- chisel - undocumented, not on $PATH, found by a filesystem sweep ---
mkdir -p /opt/net-tools
cp /opt/build/chisel /opt/net-tools/chisel
chmod 755 /opt/net-tools/chisel

touch "$PROVISION_MARK"

# --- sshd -----------------------------------------------------------------
install -m 644 /opt/build/sshd_config.d_lab.conf /etc/ssh/sshd_config.d/lab.conf

start_services
