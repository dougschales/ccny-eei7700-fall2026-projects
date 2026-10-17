FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# A plain pentest workstation - this week's skill is enumerating and
# abusing local Linux privilege-escalation vectors over an SSH session,
# not running exploit frameworks, so the toolset is deliberately light.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    sshpass \
    nmap \
    netcat-openbsd \
    curl \
    wget \
    python3 \
    gcc \
    man-db \
    nano \
    vim \
    tmux \
    procps \
    iputils-ping \
    net-tools \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
