# Fully-qualified image reference - plain "mariadb:10.11" fails to
# resolve on stock Ubuntu 22.04 podman (see projects/week5/internal-db/
# Dockerfile for the short-name-resolution details).
FROM docker.io/library/mariadb:10.11

# iptables locks this database down to only accept connections from
# pivot's INTERNAL-NET ip - enforced inside this container's own network
# namespace (see entrypoint-wrapper.sh). Not compose `networks.internal:
# true`: that's host-firewall-dependent and unreliable across podman
# versions/hosts - same reasoning as week5's docker-compose.yml.
RUN apt-get update && apt-get install -y --no-install-recommends iptables \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/entrypoint-wrapper.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["mariadbd"]
