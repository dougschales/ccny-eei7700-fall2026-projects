FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Update system and install web application testing, network pivoting,
# and general enumeration/exploitation tooling. Also restore man pages
# (Ubuntu Docker images strip them by default via 'unminimize').
RUN apt-get update && yes | unminimize && apt-get update && apt-get install -y man-db manpages manpages-posix && apt-get install -y \
    nmap \
    netcat-openbsd \
    curl \
    wget \
    file \
    gobuster \
    ffuf \
    whatweb \
    python3 \
    python3-pip \
    default-mysql-client \
    jq \
    nano \
    vim \
    tmux \
    procps \
    iputils-ping \
    net-tools \
    dnsutils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install python helper tools/libraries
RUN pip3 install --no-cache-dir requests

# Create student workspace directory
WORKDIR /workspace

# Customize bash prompt for security testing workstation
RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
