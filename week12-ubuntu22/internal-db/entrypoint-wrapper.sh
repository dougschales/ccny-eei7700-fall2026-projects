#!/bin/bash
set -e

# Only build-ci's internal-net address may reach this database - same
# self-firewalling approach as week11's db/entrypoint-wrapper.sh.
BUILD_CI_IP="${BUILD_CI_INTERNAL_IP:-172.42.1.11}"

iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s "$BUILD_CI_IP" --dport 3306 -j ACCEPT

echo "[+] internal-db: accepting port 3306 only from $BUILD_CI_IP"

exec docker-entrypoint.sh "$@"
