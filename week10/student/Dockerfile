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

WORKDIR /workspace

RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
