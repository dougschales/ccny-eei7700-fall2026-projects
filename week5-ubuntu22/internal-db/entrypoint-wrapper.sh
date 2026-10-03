#!/bin/bash
set -e

# Same self-firewalling approach as internal-api/entrypoint.sh: lock this
# database down to only accept connections from webapp's internal IP,
# enforced inside this container's OWN network namespace rather than via
# compose `networks.internal: true` (host-firewall-dependent, broke on
# Ubuntu's older podman/netavark during testing - see docker-compose.yml).
WEBAPP_IP="${WEBAPP_INTERNAL_IP:-172.35.1.10}"

iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s "$WEBAPP_IP" --dport 3306 -j ACCEPT

echo "[+] internal-db: accepting port 3306 only from $WEBAPP_IP"

exec docker-entrypoint.sh "$@"
