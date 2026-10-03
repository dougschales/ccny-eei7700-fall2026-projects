#!/bin/bash
set -e

# Lock this service down to only accept connections from webapp's internal
# IP. Enforced inside this container's OWN network namespace so it holds
# regardless of the host's podman/CNI network-driver version - see the
# cross-platform note in docker-compose.yml: we deliberately do not rely
# on compose `networks.internal: true` for this.
WEBAPP_IP="${WEBAPP_INTERNAL_IP:-172.35.1.10}"

iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s "$WEBAPP_IP" --dport 8080 -j ACCEPT

echo "[+] internal-api: accepting port 8080 only from $WEBAPP_IP"
exec python3 /opt/app/app.py
