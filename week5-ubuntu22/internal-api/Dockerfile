FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# iptables locks this service down to only accept connections from
# webapp's internal IP - enforced inside this container's own network
# namespace so it works the same regardless of the host's podman/CNI
# network backend (see docker-compose.yml).
RUN apt-get update && apt-get install -y --no-install-recommends iptables \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask

RUN mkdir -p /opt/app
COPY app.py /opt/app/app.py
COPY entrypoint.sh /opt/app/entrypoint.sh
RUN chmod +x /opt/app/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/opt/app/entrypoint.sh"]
