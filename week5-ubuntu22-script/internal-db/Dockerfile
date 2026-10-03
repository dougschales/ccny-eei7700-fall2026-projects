# Fully-qualified image reference - plain "mariadb:10.11" fails on stock
# Ubuntu 22.04 podman: its bundled shortnames.conf aliases "python" and
# "ubuntu" to docker.io, but not "mariadb", and Ubuntu's podman ships no
# unqualified-search-registries fallback, so the short name can't resolve
# at all ("short-name ... did not resolve to an alias"). Fully-qualifying
# it sidesteps host shortname/registry config entirely.
FROM docker.io/library/mariadb:10.11

# iptables locks this database down to only accept connections from
# webapp's internal IP - enforced inside this container's own network
# namespace (see entrypoint-wrapper.sh and the cross-platform note in
# docker-compose.yml: we do not rely on compose `networks.internal: true`,
# which is host-firewall-dependent and broke on Ubuntu's older
# podman/netavark during testing).
RUN apt-get update && apt-get install -y --no-install-recommends iptables \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/entrypoint-wrapper.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["mariadbd"]
