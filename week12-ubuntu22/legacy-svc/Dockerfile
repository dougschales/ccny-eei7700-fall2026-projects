FROM docker.io/library/python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcap2-bin \
    passwd \
    curl \
    ca-certificates \
    gzip \
    procps \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# chisel - same pinned release as build-ci's copy, arch-matched at build
# time. Undocumented, not on $PATH - found by a filesystem sweep, same
# convention as week11's pivot host.
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

# vsftpd 2.3.4 backdoor emulator binds port 21 (privileged) as the
# non-root ftpsvc account - grant via file capability rather than
# running the service as root (that would hand students root the moment
# they land the backdoor shell, skipping the privesc stage entirely).
RUN setcap cap_net_bind_service=+ep "$(readlink -f "$(command -v python3)")"

COPY app.py /opt/app.py
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

EXPOSE 21 6200

ENTRYPOINT ["/opt/entrypoint.sh"]
