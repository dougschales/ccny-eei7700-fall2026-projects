#!/bin/bash
set -e

# Only legacy-svc's core-net address may reach this database.
LEGACY_SVC_IP="${LEGACY_SVC_CORE_IP:-172.42.2.30}"

iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s "$LEGACY_SVC_IP" --dport 3306 -j ACCEPT

echo "[+] core-finance: accepting port 3306 only from $LEGACY_SVC_IP"

exec docker-entrypoint.sh "$@"
