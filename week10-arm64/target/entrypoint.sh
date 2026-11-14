#!/bin/bash
set -e

PROVISION_MARK=/opt/.week10_provisioned

if [ -f "$PROVISION_MARK" ]; then
    echo "[+] Already provisioned - restarting services only."
    service xinetd start
    service cron start
    python3 /opt/app/docs_app.py &
    echo "[+] Restarted xinetd, cron, and the docs portal."
    wait -n
fi

echo "[+] Initializing Week 10 binary-exploitation target..."

# --- Low-privileged service account that runs statusd -------------------
useradd -r -M -s /usr/sbin/nologin svc

# --- Build statusd with the mitigations that make a classic stack smash
# practical, disabled on purpose for this exercise (see
# ../../../Week10_Project/slides.html for what each flag removes):
#   -fno-stack-protector   no stack canary
#   -no-pie                fixed, predictable code addresses (no PIE/ASLR
#                           for the executable's own segments)
#   -z execstack            stack is executable, so injected shellcode can
#                           run directly from the overflowed buffer
# ASLR for the *stack* itself is disabled per-process below via
# `setarch -R` in statusd-launch, rather than writing
# /proc/sys/kernel/randomize_va_space - that sysctl is host-wide, not
# namespaced, and would weaken ASLR for every other process on the
# machine, not just this lab.
gcc -O0 -fno-stack-protector -no-pie -z execstack \
    -o /usr/local/bin/statusd /opt/build/statusd.c
chmod 755 /usr/local/bin/statusd

cat > /usr/local/bin/statusd-launch <<'EOF'
#!/bin/sh
exec setarch "$(uname -m)" -R /usr/local/bin/statusd
EOF
chmod 755 /usr/local/bin/statusd-launch

install -m 644 /opt/build/statusd.xinetd /etc/xinetd.d/statusd

# --- Privilege-escalation vector: a second, local overflow, triggered by
# root's cron instead of the network ---------------------------------
# diagtool has the exact same bug shape as statusd (read() into an
# undersized stack buffer, same mitigations disabled below). A root cron
# job feeds it whatever is in /var/spool/fleet/pending.dat every minute -
# a spool file svc (the account landed via the statusd overflow) can
# write to. Landing shellcode through diagtool, rather than statusd, is
# what actually gets you root: the same technique, applied a second
# time, fired by cron instead of a network client.
#
# This runs as plain root, not via a SUID bit: a SUID exec changes the
# process's credentials (uid to the file owner), and the kernel resets
# a process's ASLR back on at exactly that kind of credential-raising
# transition regardless of personality(ADDR_NO_RANDOMIZE) - the same
# hardening that stops a SUID binary from inheriting a caller's
# weakened security settings also defeats this exercise's whole "no
# ASLR" premise. Root's cron already starts diagtool AS root (no
# transition to detect), so that reset never fires here.
gcc -O0 -fno-stack-protector -no-pie -z execstack \
    -o /usr/local/bin/diagtool /opt/build/diagtool.c
chmod 755 /usr/local/bin/diagtool

cat > /usr/local/bin/diagtool-launch <<'EOF'
#!/bin/sh
exec setarch "$(uname -m)" -R /usr/local/bin/diagtool < /var/spool/fleet/pending.dat
EOF
chmod 755 /usr/local/bin/diagtool-launch

mkdir -p /var/spool/fleet
touch /var/spool/fleet/pending.dat
chown svc:svc /var/spool/fleet/pending.dat
chmod 644 /var/spool/fleet/pending.dat

cat > /etc/cron.d/diagtool <<'EOF'
* * * * * root /usr/local/bin/diagtool-launch >/dev/null 2>&1
EOF
chmod 644 /etc/cron.d/diagtool

# --- Flag: landed a shell as svc via the statusd overflow ----------------
mkdir -p /home/svc
echo "FLAG{statusd_stack_smash_shell_as_svc}" > /home/svc/.overflow_flag.txt
chown svc:svc /home/svc/.overflow_flag.txt
chmod 600 /home/svc/.overflow_flag.txt

# --- Flag: root, via the diagtool cron overflow ---------------------------
echo "FLAG{diagtool_cron_overflow_root}" > /root/privesc_complete.txt
chmod 600 /root/privesc_complete.txt

# --- Docs portal: public docs plus the non-linked internal release -------
# that leaks statusd's binary and source (same LFI bug class as Week 5).
mkdir -p /opt/app/docs /opt/app/internal/releases
cat > /opt/app/docs/README.txt <<'EOF'
FleetOps status collector - rollout notes.
The collector listens on TCP/7777 and logs a one-line status message
from each fleet node. Ops documentation lives in this portal.
EOF
cat > /opt/app/docs/network-notice.txt <<'EOF'
Reminder: statusd is intentionally unauthenticated on the internal
segment. Do not expose this service beyond the fleet VLAN.
EOF
cp /usr/local/bin/statusd /opt/app/internal/releases/statusd
cp /opt/build/statusd.c /opt/app/internal/releases/statusd.c
cp /opt/build/statusd.xinetd /opt/app/internal/releases/statusd.xinetd
cat > /opt/app/internal/releases/RELEASE_NOTES.txt <<'EOF'
statusd 1.4 release build - matches the binary currently deployed on
TCP/7777. Source included for the next code review pass.
FLAG{lfi_leaked_statusd_binary_and_source}
EOF
# An on-call engineer's leftover repro notes from a prior ticket - the
# kind of stray file a real internal release share accumulates over
# time. Gives away nothing about the overflow itself, just how to run
# this binary outside of xinetd the same way xinetd actually does -
# genuinely useful, not just flavor text (see statusd.xinetd for the
# config this note is explaining).
cat > /opt/app/internal/releases/oncall_notes.txt <<'EOF'
statusd repro notes - ticket OPS-4417
--------------------------------------
Chasing the "resets under load" ticket. Wasted most of an afternoon
because running the binary by hand from an interactive shell behaves
differently from how xinetd actually launches it - turns out xinetd
doesn't hand the service a clean environment. It passes through
whatever locale variables were sitting in ITS OWN environment at
startup (all empty on this box, but still present on the child's
environment - diffed /proc/<pid>/environ against a real xinetd-spawned
worker to confirm), plus one variable it sets itself per connection
(REMOTE_HOST, the client's address).

Copying the exact invocation here so the next person debugging this
doesn't lose an afternoon to it too. Run this from wherever you drop
the binary - path matters as much as the env does, so keep it at
/usr/local/bin/statusd, not /tmp:

env -i \
  REMOTE_HOST="::ffff:172.40.0.5" \
  LANGUAGE= LC_TIME= LC_CTYPE= LC_MONETARY= TERM= LC_COLLATE= \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  LC_ADDRESS= LANG= LC_TELEPHONE= LC_MESSAGES= LC_NAME= LC_MEASUREMENT= \
  LC_IDENTIFICATION= LC_ALL= PWD=/ LC_NUMERIC= LC_PAPER= \
  setarch "$(uname -m)" -R /usr/local/bin/statusd

- M.
EOF
chmod -R a+rX /opt/app/docs /opt/app/internal

touch "$PROVISION_MARK"

# --- xinetd ------------------------------------------------------------
service xinetd start
echo "[+] Started xinetd (statusd on 7777)"

# --- cron (drives the diagtool privesc vector) ---------------------------
service cron start
echo "[+] Started cron (diagtool runs against the spool file every minute)"

# --- Docs portal ---------------------------------------------------------
python3 /opt/app/docs_app.py &
echo "[+] Started docs portal on 80"

echo "[+] Target ready."
wait -n
