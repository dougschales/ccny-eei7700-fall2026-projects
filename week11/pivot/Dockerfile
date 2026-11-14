FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    openssh-server \
    cron \
    default-mysql-client \
    curl \
    ca-certificates \
    iproute2 \
    procps \
    gzip \
    && rm -rf /var/lib/apt/lists/*

# internal-db offers no TLS (see projects/week11/db/Dockerfile) but
# current default-mysql-client builds require SSL by default - same
# idea as week5's webapp image, though the mysql-client-8.0 package
# that "default-mysql-client" resolves to on this Ubuntu 22.04 mirror
# uses ssl-mode=DISABLED, not the older ssl=0 syntax (confirmed by
# testing - ssl=0 makes this client reject its own config file outright).
RUN mkdir -p /etc/mysql/conf.d && \
    printf '[client]\nssl-mode=DISABLED\n' > /etc/mysql/conf.d/no-ssl.cnf

# This client exists only so root's cron healthcheck below can reach
# db directly - it is NOT meant to be a free ride for whichever
# non-root account gets compromised. default-mysql-client installs it
# world-executable, and db's firewall trusts any connection from
# pivot's own internal IP, so without this the entire pivoting lesson
# (ssh -D blocked -> chisel reverse socks -> proxychains) is skippable
# by just running `mysql -h 172.41.1.20 ...` straight from an SSH
# session on pivot. Locking it to root closes that.
RUN chmod 700 /usr/bin/mysql /usr/bin/mysqladmin /usr/bin/mysqldump \
      /usr/bin/mysqlshow /usr/bin/mysql_config_editor

# chisel - pinned release, matched to the build host's own architecture
# (amd64/arm64) so this image builds correctly on x86_64 hosts and on
# Apple Silicon/arm64 hosts alike without needing a Go toolchain in the
# image. Deliberately NOT on $PATH and NOT documented anywhere for
# students - it's meant to be found by enumerating the box, the way a
# leftover admin tool left on a real compromised host would be.
ARG CHISEL_VERSION=1.10.1
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) CH_ARCH=amd64 ;; \
        arm64) CH_ARCH=arm64 ;; \
        *) echo "unsupported arch: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/net-tools; \
    curl -fsSL -o /tmp/chisel.gz \
      "https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION}/chisel_${CHISEL_VERSION}_linux_${CH_ARCH}.gz"; \
    gunzip -c /tmp/chisel.gz > /opt/net-tools/chisel; \
    rm -f /tmp/chisel.gz; \
    chmod 755 /opt/net-tools/chisel

# Web content, including a backup archive that should never have been
# left under the docroot - a realistic "ops left something behind"
# leak, only discoverable via recon (robots.txt hints at the directory;
# the filename itself has to be found separately).
COPY webroot/ /var/www/html/
RUN mkdir -p /var/www/html/ops-archive /opt/build/backup-src
COPY files/deploy-notes.txt files/maintenance-window.txt files/ssl-renewal-checklist.txt /opt/build/backup-src/
RUN tar -C /opt/build/backup-src -czf /var/www/html/ops-archive/backup.tar.gz \
      deploy-notes.txt maintenance-window.txt ssl-renewal-checklist.txt && \
    rm -rf /opt/build/backup-src && \
    chown -R www-data:www-data /var/www/html

RUN mkdir -p /opt/monitoring
COPY files/db-healthcheck.sh /opt/monitoring/db-healthcheck.sh
COPY files/db-healthcheck-cron /opt/build/db-healthcheck-cron
COPY files/sshd_config.d_lab.conf /opt/build/sshd_config.d_lab.conf
COPY entrypoint.sh /opt/build/entrypoint.sh
RUN chmod +x /opt/build/entrypoint.sh && chmod 744 /opt/monitoring/db-healthcheck.sh

EXPOSE 80 22

ENTRYPOINT ["/opt/build/entrypoint.sh"]
