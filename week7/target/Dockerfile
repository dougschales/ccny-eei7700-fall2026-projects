FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    cron \
    gcc \
    libc6-dev \
    libcap2-bin \
    python3 \
    procps \
    iproute2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/build
COPY files/diag.c /opt/build/diag.c
COPY files/cleanup.sh /opt/build/cleanup.sh
COPY files/maintenance-cron /opt/build/maintenance-cron
COPY files/trainee-sudoers /opt/build/trainee-sudoers
COPY files/sshd_config.d_lab.conf /opt/build/sshd_config.d_lab.conf
COPY entrypoint.sh /opt/build/entrypoint.sh
RUN chmod +x /opt/build/entrypoint.sh /opt/build/cleanup.sh

EXPOSE 22

ENTRYPOINT ["/opt/build/entrypoint.sh"]
