#!/bin/bash
set -e

# Idempotency guard: this container has restart: unless-stopped, and a
# crashed/rebooted/manually-restarted container re-runs this entrypoint
# against its *same* writable layer, where trainee/webadmin/etc. already
# exist. Without this guard, the useradd calls below fail immediately
# under `set -e` on every restart, sshd never starts, and the target
# silently crash-loops forever - a restart permanently breaks the lab
# until someone notices and rebuilds. Skip straight to sshd if already
# provisioned.
if [ -f /opt/.week8_provisioned ]; then
    echo "[+] Already provisioned - restarting sshd only."
    mkdir -p /var/run/sshd
    /usr/sbin/sshd
    echo "[+] Started SSH server on port 22"
    exec tail -f /dev/null
fi

echo "[+] Initializing Week 8 credential-harvesting target..."

# Pin the shadow hash scheme to SHA-512 crypt ($6$) explicitly. Newer
# Ubuntu base image updates default to yescrypt ($y$), which this week's
# cracking path (and the syllabus's "Linux shadow hashes" discussion)
# doesn't cover - without this, the lab's hash format would silently
# depend on exactly when each student's base image was pulled.
sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' /etc/login.defs
grep -q '^ENCRYPT_METHOD' /etc/login.defs || echo 'ENCRYPT_METHOD SHA512' >> /etc/login.defs
# chpasswd goes through PAM on this image, and pam_unix.so's own
# "yescrypt" argument overrides login.defs - patch it too.
sed -i 's/pam_unix\.so obscure yescrypt/pam_unix.so obscure sha512/' /etc/pam.d/common-password

# --- Foothold account: password known only to the wordlist ---------------
# Unlike previous weeks, the password is never handed out - cracking it
# (online, with Hydra) is the first exercise.
useradd -m -s /bin/bash trainee
echo "trainee:Harvest2024" | chpasswd
echo "FLAG{online_bruteforce_ssh_foothold}" > /home/trainee/welcome_flag.txt
chmod 644 /home/trainee/welcome_flag.txt
chown trainee:trainee /home/trainee/welcome_flag.txt

# --- Vector 1: a forgotten, world-readable shadow backup -----------------
# "Last known good" backups like this are exactly how real shadow hashes
# leak - nobody meant to leave it world-readable, it just never got
# cleaned up after the restore.
useradd -m -s /bin/bash webadmin
echo "webadmin:Passw0rd99" | chpasswd
mkdir -p /home/webadmin
cat > /home/webadmin/admin_notes.txt <<'EOF'
Internal notes - web admin account
FLAG{shadow_backup_crypt_crack}
EOF
chmod 600 /home/webadmin/admin_notes.txt
chown webadmin:webadmin /home/webadmin/admin_notes.txt

mkdir -p /var/backups
{
    grep -E '^(root|daemon|bin|sys):' /etc/shadow
    grep '^webadmin:' /etc/shadow
} > /var/backups/shadow.bak
chmod 644 /var/backups/shadow.bak
chown root:root /var/backups/shadow.bak

# --- Vector 2: a leftover application database export --------------------
# The app's own user table got exported for a migration and never deleted.
# It stores its own bcrypt hashes - independent of the OS account's
# shadow hash - but the account holder reused the same password in both
# places, which is exactly the kind of reuse that makes credential
# harvesting worthwhile in the real world.
useradd -m -s /bin/bash dbadmin
echo "dbadmin:Summer2024" | chpasswd
mkdir -p /home/dbadmin
cat > /home/dbadmin/db_credentials_flag.txt <<'EOF'
Database admin account - confirmed
FLAG{bcrypt_dbdump_crack}
EOF
chmod 600 /home/dbadmin/db_credentials_flag.txt
chown dbadmin:dbadmin /home/dbadmin/db_credentials_flag.txt

mkdir -p /opt/webapp/exports
DBADMIN_HASH=$(htpasswd -nbB dbadmin 'Summer2024' | cut -d: -f2)
DECOY_HASH=$(htpasswd -nbB legacy_report 'Xk9#qRv2mWz7' | cut -d: -f2)
cat > /opt/webapp/exports/users_backup.csv <<EOF
username,password_hash
dbadmin,${DBADMIN_HASH}
legacy_report,${DECOY_HASH}
EOF
chmod 644 /opt/webapp/exports/users_backup.csv
chmod 755 /opt/webapp /opt/webapp/exports
chown -R root:root /opt/webapp

# --- Vector 3: a forgotten, encrypted SSH private key ---------------------
# trainee kept a backup copy of a service account's key around after a
# key rotation and never deleted it. The key itself is readable - it's
# useless without the passphrase, which only exists in the wordlist.
useradd -m -s /bin/bash opskey
passwd -l opskey >/dev/null   # no password login - key-only account
mkdir -p /home/opskey/.ssh
ssh-keygen -t rsa -b 2048 -f /tmp/opskey_key -N "Cracked123" -C opskey -q
cp /tmp/opskey_key.pub /home/opskey/.ssh/authorized_keys
chmod 700 /home/opskey/.ssh
chmod 600 /home/opskey/.ssh/authorized_keys
chown -R opskey:opskey /home/opskey/.ssh

mkdir -p /home/trainee/backups
cp /tmp/opskey_key /home/trainee/backups/id_rsa_opskey.bak
chmod 644 /home/trainee/backups/id_rsa_opskey.bak
chown -R trainee:trainee /home/trainee/backups
rm -f /tmp/opskey_key /tmp/opskey_key.pub

cat > /home/opskey/service_account_flag.txt <<'EOF'
opskey service account - key cracked
FLAG{ssh_key_passphrase_crack}
EOF
chmod 600 /home/opskey/service_account_flag.txt
chown opskey:opskey /home/opskey/service_account_flag.txt

# --- Final flag: opskey has one narrowly-scoped sudo rule -----------------
# Ops reviews the incident-response summary after any confirmed
# compromise - a legitimate, narrowly-scoped NOPASSWD rule, not a
# privilege-escalation bug to abuse (that was last week).
echo "FLAG{full_credential_chain_compromised}" > /root/compromise_confirmed.txt
chmod 600 /root/compromise_confirmed.txt
echo "opskey ALL=(root) NOPASSWD: /usr/bin/cat /root/compromise_confirmed.txt" \
    > /etc/sudoers.d/opskey
chmod 440 /etc/sudoers.d/opskey

touch /opt/.week8_provisioned

# --- sshd ------------------------------------------------------------
install -m 644 /opt/build/sshd_config.d_lab.conf /etc/ssh/sshd_config.d/lab.conf
mkdir -p /var/run/sshd
/usr/sbin/sshd
echo "[+] Started SSH server on port 22"

echo "[+] Target ready."
exec tail -f /dev/null
