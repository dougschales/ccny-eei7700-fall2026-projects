FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install required services and dependencies
RUN apt-get update && apt-get install -y \
    vsftpd \
    openssh-server \
    apache2 \
    redis-server \
    rpcbind \
    nfs-kernel-server \
    nfs-common \
    python3 \
    python3-pip \
    net-tools \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir flask

# Create service configuration directory
RUN mkdir -p /opt/services

# Copy configuration files and service scripts
COPY services/vsftpd.conf /etc/vsftpd.conf
COPY services/redis.conf /etc/redis/redis.conf
COPY services/banner_service.py /opt/services/banner_service.py
COPY services/nfs_service.py /opt/services/nfs_service.py
COPY services/web_app.py /opt/services/web_app.py
COPY services/apache_site.html /opt/services/apache_site.html
COPY services/id_rsa.pub /opt/services/id_rsa.pub
COPY services/entrypoint.sh /opt/services/entrypoint.sh

RUN chmod +x /opt/services/entrypoint.sh \
    /opt/services/banner_service.py \
    /opt/services/nfs_service.py \
    /opt/services/web_app.py

EXPOSE 80 8080 21 2222 6379 9001 2049

ENTRYPOINT ["/opt/services/entrypoint.sh"]
