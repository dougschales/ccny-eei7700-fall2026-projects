FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# gdb/gcc/binutils to analyze the leaked statusd binary+source offline;
# python3 + pwntools to build the exploit; nmap/curl for recon and
# pulling the leak off the docs portal; netcat as a manual fallback.
RUN apt-get update && apt-get install -y --no-install-recommends \
    gdb \
    gcc \
    binutils \
    file \
    nmap \
    curl \
    netcat-openbsd \
    python3 \
    python3-pip \
    procps \
    iproute2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir pwntools

# diagtool-repro: mechanical setup only, for reproducing root's cron
# invocation of diagtool locally (same ASLR-off, same minimal cron
# environment - see solutions/SOLUTION_W10.md SS4 for why this specific
# env is cron's, not a target-specific secret). Takes your own
# exfiltrated diagtool binary, launches it the way cron does, and
# prints the PID - attaching gdb and finding the offset/address is
# still on you.
RUN cat > /usr/local/bin/diagtool-repro <<'EOF'
#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "usage: diagtool-repro <path-to-your-exfiltrated-diagtool-binary>" >&2
    exit 1
fi

cp "$1" /usr/local/bin/diagtool
chmod +x /usr/local/bin/diagtool

fifo=$(mktemp -u /tmp/diagtool-repro.XXXXXX)
mkfifo "$fifo"
exec 3<>"$fifo"

# setsid: without this, the backgrounded process is tied to this exec
# session and dies the moment this script's own shell exits - it needs
# to survive on its own so you can attach gdb to it from a separate
# command afterward. $!, not `pgrep -n`: pgrep-by-name races against
# any other diagtool process still being cleaned up and can report the
# wrong pid; $! is bash's own exact record of the pid it just forked,
# unaffected by exec() (setarch/env replace the process image in
# place, same pid throughout, never fork again).
setsid env -i \
  HOME=/root LOGNAME=root SHELL=/bin/sh PWD=/root \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin \
  setarch "$(uname -m)" -R /usr/local/bin/diagtool <&3 >/tmp/diagtool-repro.out 2>&1 &
pid=$!
disown

sleep 0.2
if ! kill -0 "$pid" 2>/dev/null; then
    echo "diagtool (pid $pid) exited immediately - something's wrong with the binary or the environment; check /tmp/diagtool-repro.out" >&2
    exit 1
fi

echo "diagtool running locally as pid $pid, blocked waiting for input on fd 3 (write to $fifo to feed it)."
echo "attach with: gdb -q -p $pid"
EOF
RUN chmod +x /usr/local/bin/diagtool-repro

WORKDIR /workspace

RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
