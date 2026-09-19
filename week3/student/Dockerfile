FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Update system and install security scanning, enumeration, network analysis, and cracking tools
RUN apt-get update && yes | unminimize && apt-get update && apt-get install -y man-db manpages manpages-posix && apt-get install -y \
    nmap \
    masscan \
    netcat-openbsd \
    nikto \
    gobuster \
    ffuf \
    hydra \
    tshark \
    tcpdump \
    curl \
    wget \
    python3 \
    python3-pip \
    smbclient \
    redis-tools \
    openssh-client \
    ftp \
    john \
    fcrackzip \
    zip \
    unzip \
    jq \
    nano \
    vim \
    tmux \
    procps \
    iputils-ping \
    net-tools \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install python helper tools/libraries
RUN pip3 install --no-cache-dir requests pycryptodome

# Create student workspace directory
WORKDIR /workspace

# Customize bash prompt for security testing workstation
RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
