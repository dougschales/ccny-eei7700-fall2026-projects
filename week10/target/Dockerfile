FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    gdb \
    xinetd \
    cron \
    python3 \
    python3-pip \
    procps \
    iproute2 \
    util-linux \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir flask

RUN mkdir -p /opt/build /opt/app
COPY files/statusd.c /opt/build/statusd.c
COPY files/diagtool.c /opt/build/diagtool.c
COPY files/statusd.xinetd /opt/build/statusd.xinetd
COPY files/docs_app.py /opt/app/docs_app.py
COPY entrypoint.sh /opt/build/entrypoint.sh
RUN chmod +x /opt/build/entrypoint.sh

EXPOSE 80 7777

ENTRYPOINT ["/opt/build/entrypoint.sh"]
