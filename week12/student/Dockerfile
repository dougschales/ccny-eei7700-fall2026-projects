FROM docker.io/kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    metasploit-framework \
    nmap \
    ffuf \
    john \
    openssh-client \
    mariadb-client \
    proxychains4 \
    curl \
    wget \
    jq \
    netcat-openbsd \
    file \
    python3 \
    python3-pip \
    man-db \
    nano \
    vim \
    tmux \
    procps \
    iputils-ping \
    net-tools \
    iproute2 \
    dnsutils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# internal-db / core-finance offer no TLS. Kali's "mariadb-client" package
# resolves to the REAL MariaDB client (confirmed via `mysql --version`),
# which wants the older `ssl=0` syntax - NOT `ssl-mode=DISABLED` (that's
# what weeks 5/11's Ubuntu `default-mysql-client` resolves to, a different
# binary with different accepted syntax; `ssl-mode=DISABLED` makes THIS
# client reject its own config outright with "unknown variable").
RUN mkdir -p /etc/mysql/conf.d && \
    printf '[client]\nssl=0\n' > /etc/mysql/conf.d/no-ssl.cnf

# chisel - same pinned release as build-ci/legacy-svc's copies.
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

COPY wordlists/ /usr/share/wordlists/week12/
RUN gunzip /usr/share/wordlists/week12/db-hash-wordlist.txt.gz
COPY proxychains4.conf /etc/proxychains4.conf

WORKDIR /workspace

RUN echo 'export PS1="\[\033[01;32m\]student@pentest-workstation\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

CMD ["sleep", "infinity"]
