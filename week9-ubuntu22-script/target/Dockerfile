FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-flask \
    openssh-server \
    openssh-client \
    sudo \
    tar \
    ca-certificates \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/build /opt/app/data/attachments
COPY files/api_app.py /opt/app/api_app.py
COPY files/sshd_config.d_lab.conf /opt/build/sshd_config.d_lab.conf
COPY files/opskey-sudoers /opt/build/opskey-sudoers
COPY entrypoint.sh /opt/build/entrypoint.sh
RUN chmod +x /opt/build/entrypoint.sh

EXPOSE 22 8080

ENTRYPOINT ["/opt/build/entrypoint.sh"]
