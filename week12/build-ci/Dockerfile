FROM docker.io/library/ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-flask \
    openssh-server \
    openssh-client \
    sudo \
    tar \
    curl \
    ca-certificates \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

# chisel - pinned release, arch-matched at build time (same approach as
# week11's pivot/student images).
ARG CHISEL_VERSION=1.10.1
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) CH_ARCH=amd64 ;; \
        arm64) CH_ARCH=arm64 ;; \
        *) echo "unsupported arch: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/build; \
    curl -fsSL -o /tmp/chisel.gz \
      "https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION}/chisel_${CHISEL_VERSION}_linux_${CH_ARCH}.gz"; \
    gunzip -c /tmp/chisel.gz > /opt/build/chisel; \
    rm -f /tmp/chisel.gz; \
    chmod 755 /opt/build/chisel

RUN mkdir -p /opt/app/data/artifacts
COPY files/api_app.py /opt/app/api_app.py
COPY files/sshd_config.d_lab.conf /opt/build/sshd_config.d_lab.conf
COPY files/ci-runner-sudoers /opt/build/ci-runner-sudoers
COPY files/network-notes.txt /opt/build/network-notes.txt
COPY entrypoint.sh /opt/build/entrypoint.sh
RUN chmod +x /opt/build/entrypoint.sh

EXPOSE 22 8080

ENTRYPOINT ["/opt/build/entrypoint.sh"]
