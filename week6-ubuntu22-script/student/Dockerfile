FROM docker.io/kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

# Metasploit + nmap + exploitdb (searchsploit) for identifying unpatched
# versions and driving known-CVE exploits. Also restore man pages.
RUN apt-get update && apt-get install -y --no-install-recommends \
    metasploit-framework \
    nmap \
    netcat-openbsd \
    exploitdb \
    curl \
    wget \
    file \
    python3 \
    python3-pip \
    man-db \
    nano \
    vim \
    tmux \
    procps \
    iputils-ping \
    net-tools \
    dnsutils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --break-system-packages requests

# Create student workspace directory
WORKDIR /workspace

# Customize bash prompt for security testing workstation
RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
