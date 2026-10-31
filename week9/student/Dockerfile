FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# This week's skill is manual API exploration (curl + jq), not a
# framework - plus the John/wordlist cracking workflow carried over from
# Week 8 to decrypt the key the API eventually leaks, and an SSH client
# for the final foothold.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    python3 \
    python3-requests \
    openssh-client \
    john \
    nmap \
    ca-certificates \
    man-db \
    nano \
    vim \
    tmux \
    procps \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY wordlists/week9-wordlist.txt /usr/share/wordlists/week9-wordlist.txt

RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
