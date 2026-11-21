# Fully-qualified image reference - short names fail to resolve on stock
# Ubuntu 22.04 podman (see cross-platform podman notes elsewhere in this repo).
FROM docker.io/library/mariadb:10.11

# Self-firewalled to only accept connections from build-ci's internal IP,
# enforced inside this container's own network namespace (not compose
# networks.internal: true - unreliable across podman versions/hosts).
RUN apt-get update && apt-get install -y --no-install-recommends iptables \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/entrypoint-wrapper.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["mariadbd"]
