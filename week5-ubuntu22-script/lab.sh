#!/usr/bin/env bash
#
# Week 5 lab launcher - plain podman, no podman-compose.
#
# This is a third variant of the Week 5 lab, built specifically for stock
# Ubuntu 22.04 (podman 3.4.4). Instead of patching a podman-compose-generated
# CNI config after the fact (see ../week5-ubuntu22/), it drives podman directly
# so networking never goes through podman-compose at all. The app code and the
# five-flag chain are identical to ../week5/.
#
# Everything here uses only podman-3.4-safe syntax:
#   - `podman network create --subnet ...`
#   - `podman run --network <name> --ip <addr> --network-alias <name>`
#     (a single network with a static IP is supported on 3.4; the newer
#      `--network name:ip=...,alias=...` and `--ip` on `network connect` are
#      NOT, so we avoid them)
#   - `podman network connect --alias <name> <net> <container>` to add the
#     second network to the dual-homed webapp
#
# Usage:
#   ./lab.sh up        build images, create networks, start all containers
#   ./lab.sh down      stop/remove containers and remove the networks
#   ./lab.sh status    show container + network state
#   ./lab.sh shell     drop into a shell on the student workstation
#   ./lab.sh rebuild   down, then up (force a clean rebuild)

set -euo pipefail

# --- configuration (mirrors ../week5/docker-compose.yml exactly) -------------
EDGE_NET="week5_edge_net"
INT_NET="week5_internal_net"
EDGE_SUBNET="172.35.0.0/24"
INT_SUBNET="172.35.1.0/24"

WEBAPP_EDGE_IP="172.35.0.10"
WEBAPP_INT_IP="172.35.1.10"
API_IP="172.35.1.20"
DB_IP="172.35.1.30"
STUDENT_IP="172.35.0.5"

API_TOKEN="s3rv1c3_t0k3n_r3p0rt1ng_2026"
DB_ROOT_PW="r00t_only_l0cal_2026!"
DB_NAME="internal"
DB_USER="svc_pivot"
DB_PW="P1v0t_M3_2026!"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

say() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# Known stock-Ubuntu-22.04 CNI bug: the generated <net>.conflist can carry
# cniVersion "1.0.0", which the bundled (older) CNI plugins can't parse, so the
# network silently fails to attach. Because this script creates the networks
# itself, we can patch the conflist in place BEFORE any container starts - no
# recreate step needed (unlike the compose variant). No-op on systems that
# already write a supported version (e.g. modern netavark, which has no
# conflist at all).
patch_cni_version() {
  local name="$1" dir f
  for dir in \
      "${XDG_CONFIG_HOME:-$HOME/.config}/cni/net.d" \
      "/etc/cni/net.d"; do
    f="$dir/$name.conflist"
    if [ -f "$f" ] && grep -q '"cniVersion": *"1\.0\.0"' "$f" 2>/dev/null; then
      if sed -i 's/"cniVersion": *"1\.0\.0"/"cniVersion": "0.4.0"/' "$f" 2>/dev/null; then
        say "patched cniVersion 1.0.0 -> 0.4.0 in $f"
      else
        warn "found cniVersion 1.0.0 in $f but could not patch it (permission?)"
      fi
    fi
  done
}

net_exists() { podman network exists "$1" 2>/dev/null; }

create_net() {
  local name="$1" subnet="$2"
  if net_exists "$name"; then
    say "network $name already exists"
  else
    say "creating network $name ($subnet)"
    podman network create --subnet "$subnet" "$name" >/dev/null
  fi
  patch_cni_version "$name"
}

rm_container() {
  local name="$1"
  if podman container exists "$name" 2>/dev/null; then
    say "removing existing container $name"
    podman rm -f "$name" >/dev/null 2>&1 || true
  fi
}

# --- subcommands -------------------------------------------------------------
do_build() {
  say "building images"
  podman build -t week5-internal-api ./internal-api
  podman build -t week5-internal-db  ./internal-db
  podman build -t week5-webapp       ./webapp
  podman build -t week5-student      ./student
}

do_up() {
  do_build

  create_net "$EDGE_NET" "$EDGE_SUBNET"
  create_net "$INT_NET"  "$INT_SUBNET"

  # Start fresh - remove any leftovers from a previous run.
  rm_container week5_student
  rm_container week5_webapp
  rm_container week5_internal-db
  rm_container week5_internal-api

  # internal-api: internal net only, pinned IP, self-firewalls to webapp.
  say "starting internal-api ($API_IP)"
  podman run -d \
    --name week5_internal-api --hostname internal-api \
    --restart unless-stopped --init --cap-add NET_ADMIN \
    --network "$INT_NET" --ip "$API_IP" --network-alias internal-api \
    -e API_TOKEN="$API_TOKEN" \
    -e WEBAPP_INTERNAL_IP="$WEBAPP_INT_IP" \
    week5-internal-api >/dev/null

  # internal-db: internal net only, pinned IP, self-firewalls to webapp.
  say "starting internal-db ($DB_IP)"
  podman run -d \
    --name week5_internal-db --hostname internal-db \
    --restart unless-stopped --cap-add NET_ADMIN \
    --network "$INT_NET" --ip "$DB_IP" --network-alias internal-db \
    -e MARIADB_ROOT_PASSWORD="$DB_ROOT_PW" \
    -e MYSQL_DATABASE="$DB_NAME" \
    -e MYSQL_USER="$DB_USER" \
    -e MYSQL_PASSWORD="$DB_PW" \
    -e WEBAPP_INTERNAL_IP="$WEBAPP_INT_IP" \
    -v "$SCRIPT_DIR/internal-db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro,Z" \
    week5-internal-db >/dev/null

  # webapp: dual-homed. Run it on the INTERNAL net first so we can pin
  # 172.35.1.10 with the 3.4-safe `--ip` form (the firewall rules on
  # internal-api/db allow exactly that address), then attach the edge net.
  say "starting webapp (int $WEBAPP_INT_IP, edge $WEBAPP_EDGE_IP)"
  podman run -d \
    --name week5_webapp --hostname webapp \
    --restart unless-stopped --init \
    --network "$INT_NET" --ip "$WEBAPP_INT_IP" --network-alias webapp \
    week5-webapp >/dev/null
  podman network connect --alias webapp "$EDGE_NET" week5_webapp

  # student: edge net only - webapp is the only host it can reach directly.
  say "starting student ($STUDENT_IP)"
  podman run -d \
    --name week5_student --hostname student \
    --restart unless-stopped --init \
    --cap-add NET_ADMIN --cap-add NET_RAW \
    -it \
    --network "$EDGE_NET" --ip "$STUDENT_IP" --network-alias student \
    week5-student >/dev/null

  echo
  say "lab is up. Get a shell on the workstation with:  ./lab.sh shell"
  say "from there, the foothold target is http://webapp/"
}

do_down() {
  rm_container week5_student
  rm_container week5_webapp
  rm_container week5_internal-db
  rm_container week5_internal-api
  for n in "$EDGE_NET" "$INT_NET"; do
    if net_exists "$n"; then
      say "removing network $n"
      podman network rm "$n" >/dev/null 2>&1 || warn "could not remove $n (still in use?)"
    fi
  done
  say "lab is down."
}

do_status() {
  echo "== containers =="
  podman ps -a --filter "name=week5_" \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}' || true
  echo
  echo "== networks =="
  podman network ls --filter "name=week5_" || true
}

do_shell() {
  if ! podman container exists week5_student 2>/dev/null; then
    warn "student container is not running - run ./lab.sh up first"
    exit 1
  fi
  exec podman exec -it week5_student /bin/bash
}

case "${1:-}" in
  up)      do_up ;;
  down)    do_down ;;
  status)  do_status ;;
  shell)   do_shell ;;
  rebuild) do_down; do_up ;;
  *)
    echo "usage: $0 {up|down|status|shell|rebuild}" >&2
    exit 2
    ;;
esac
