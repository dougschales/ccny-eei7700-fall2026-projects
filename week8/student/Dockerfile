FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# This week's skill is cracking, not framework-driven exploitation:
# Hydra for the online SSH brute force, John the Ripper for offline
# hash cracking (shadow-style crypt(3) hashes and bcrypt), and plain
# openssh-client for a manual wordlist attack against an encrypted
# private key. Hashcat is included too (see README_W8.md) but its
# OpenCL backend inside a container with no GPU passthrough is not
# guaranteed to work on every host - John is the guaranteed path.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    sshpass \
    hydra \
    john \
    hashcat \
    ocl-icd-libopencl1 \
    ca-certificates \
    curl \
    python3 \
    man-db \
    nano \
    vim \
    tmux \
    procps \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY wordlists/week8-wordlist.txt /usr/share/wordlists/week8-wordlist.txt

RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
