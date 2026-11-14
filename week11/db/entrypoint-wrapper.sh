#!/bin/bash
set -e

# Same self-firewalling approach as week5's internal-db: lock this
# database down to only accept connections from pivot's internal-net
# IP, enforced inside this container's OWN network namespace rather
# than compose `networks.internal: true` (see Dockerfile).
PIVOT_IP="${PIVOT_INTERNAL_IP:-172.41.1.10}"

iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s "$PIVOT_IP" --dport 3306 -j ACCEPT

echo "[+] db: accepting port 3306 only from $PIVOT_IP"

exec docker-entrypoint.sh "$@"
