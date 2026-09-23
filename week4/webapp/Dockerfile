FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Flask web app + a real headless-browser "admin bot" (for the stored XSS /
# cookie theft flag) + mysql client (needed later to pivot into internal-db).
RUN apt-get update && apt-get install -y \
    python3 \
    python3-flask \
    python3-selenium \
    chromium \
    chromium-driver \
    default-mysql-client \
    iputils-ping \
    net-tools \
    iproute2 \
    procps \
    curl \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/app/data /opt/app/backup /opt/app/config

COPY app.py /opt/app/app.py
COPY admin_bot.py /opt/app/admin_bot.py
COPY backup/ /opt/app/backup/
COPY config/ /opt/app/config/
COPY entrypoint.sh /opt/app/entrypoint.sh

RUN chmod +x /opt/app/entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/opt/app/entrypoint.sh"]
