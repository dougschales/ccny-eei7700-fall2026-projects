FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    openssh-client \
    sudo \
    apache2-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/build
COPY files/sshd_config.d_lab.conf /opt/build/sshd_config.d_lab.conf
COPY entrypoint.sh /opt/build/entrypoint.sh
RUN chmod +x /opt/build/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/opt/build/entrypoint.sh"]
