FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    nmap \
    netcat-openbsd \
    curl \
    wget \
    file \
    gobuster \
    ffuf \
    default-mysql-client \
    proxychains4 \
    jq \
    nano \
    vim \
    tmux \
    procps \
    iproute2 \
    iputils-ping \
    net-tools \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# db offers no TLS - default-mysql-client builds require SSL by default
# unless told otherwise. The mysql-client-8.0 package this resolves to
# on this Ubuntu 22.04 mirror wants ssl-mode=DISABLED, not the older
# ssl=0 syntax (confirmed by testing - ssl=0 makes the client reject
# its own config file outright, breaking even `mysql --version`).
RUN mkdir -p /etc/mysql/conf.d && \
    printf '[client]\nssl-mode=DISABLED\n' > /etc/mysql/conf.d/no-ssl.cnf

# chisel - same pinned release as pivot's copy, matched to this image's
# own build architecture (amd64/arm64).
ARG CHISEL_VERSION=1.10.1
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) CH_ARCH=amd64 ;; \
        arm64) CH_ARCH=arm64 ;; \
        *) echo "unsupported arch: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/chisel.gz \
      "https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION}/chisel_${CHISEL_VERSION}_linux_${CH_ARCH}.gz"; \
    gunzip -c /tmp/chisel.gz > /usr/local/bin/chisel; \
    rm -f /tmp/chisel.gz; \
    chmod 755 /usr/local/bin/chisel

COPY wordlists/common-backups.txt /usr/share/wordlists/common-backups.txt
COPY proxychains4.conf /etc/proxychains4.conf

WORKDIR /workspace

RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
