FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-flask \
    vsftpd \
    ca-certificates \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/app /srv/ftp
COPY app/ /opt/app/
COPY ftp/ /srv/ftp/
COPY vsftpd.conf /etc/vsftpd.conf
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh && chmod -R a+rX /srv/ftp

EXPOSE 80 21 30000-30009

ENTRYPOINT ["/opt/entrypoint.sh"]
