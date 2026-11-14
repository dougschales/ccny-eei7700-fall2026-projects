#!/usr/bin/env bash
#
# Week 11 lab launcher - plain podman, no podman-compose.
#
# Built the same way as ../week7-ubuntu22-script/: stock Ubuntu 22.04
# (podman 3.4.4) has a podman-compose bug where custom networks silently
# fail to attach. Rather than patch a compose-generated CNI config after
# the fact, this script drives podman directly so the compose network
# machinery is never in the picture. The pivot/db/student images and
# app code are identical to ../week11/.
#
# Everything here uses only podman-3.4-safe syntax:
#   - `podman network create --subnet ...`
#   - `podman run --network <name> --ip <addr> --network-alias <name>`
#     (a single network with a static IP is supported on 3.4; the newer
#      `--network name:ip=...,alias=...` form is NOT, so we avoid it)
#   - pivot is attached to BOTH networks via two separate
#     `podman network connect` calls after `podman run`, since 3.4's
#     `podman run` only accepts one `--network` flag.
#
# Usage:
#   ./lab.sh up        build images, create the networks, start everything
#   ./lab.sh down      stop/remove containers and remove the networks
#   ./lab.sh status    show container + network state
#   ./lab.sh shell      drop into a shell on the student workstation
#   ./lab.sh rebuild    down, then up (force a clean rebuild)

set -euo pipefail

# --- configuration (mirrors ../week11/docker-compose.yml exactly) ----------
EDGE_NET="week11_edge_net"
EDGE_SUBNET="172.41.0.0/24"
INTERNAL_NET="week11_internal_net"
INTERNAL_SUBNET="172.41.1.0/24"

PIVOT_EDGE_IP="172.41.0.10"
PIVOT_INTERNAL_IP="172.41.1.10"
DB_IP="172.41.1.20"
STUDENT_IP="172.41.0.5"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

say() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# Known stock-Ubuntu-22.04 CNI bug: the generated <net>.conflist can carry
# cniVersion "1.0.0", which the bundled (older) CNI plugins can't parse, so
# the network silently fails to attach. Because this script creates the
# network itself, it can patch the conflist in place BEFORE any container
# starts - no recreate step needed. No-op on systems that already write a
# supported version (e.g. modern netavark, which has no conflist at all).
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
  podman build -t week11-pivot   ./pivot
  podman build -t week11-db      ./db
  podman build -t week11-student ./student
}

do_up() {
  do_build

  create_net "$EDGE_NET" "$EDGE_SUBNET"
  create_net "$INTERNAL_NET" "$INTERNAL_SUBNET"

  rm_container week11_student
  rm_container week11_pivot
  rm_container week11_db

  say "starting db ($DB_IP, internal-only)"
  podman run -d \
    --name week11_db --hostname db \
    --restart unless-stopped \
    --cap-add NET_ADMIN \
    -e MARIADB_ROOT_PASSWORD="r00t_only_l0cal_2026!" \
    -e MYSQL_DATABASE=ops_internal \
    -e MYSQL_USER=svc_monitor \
    -e MYSQL_PASSWORD="M0nit0r_2026!" \
    -e PIVOT_INTERNAL_IP="$PIVOT_INTERNAL_IP" \
    -v "$SCRIPT_DIR/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro,Z" \
    --network "$INTERNAL_NET" --ip "$DB_IP" --network-alias db \
    week11-db >/dev/null

  say "starting pivot ($PIVOT_EDGE_IP edge / $PIVOT_INTERNAL_IP internal, dual-homed)"
  podman run -d \
    --name week11_pivot --hostname pivot \
    --restart unless-stopped --init \
    --network "$EDGE_NET":"$PIVOT_EDGE_IP" \
    --network "$INTERNAL_NET":"$PIVOT_INTERNAL_IP" \
    week11-pivot >/dev/null
  # podman 3.4's `run` only takes one --network; attach the second
  say "starting student ($STUDENT_IP)"
  podman run -d \
    --name week11_student --hostname student \
    --restart unless-stopped --init \
    --cap-add NET_ADMIN --cap-add NET_RAW \
    -it \
    --network "$EDGE_NET" --ip "$STUDENT_IP" --network-alias student \
    week11-student >/dev/null

  echo
  say "lab is up. Get a shell on the workstation with:  ./lab.sh shell"
  say "from there, start recon against the edge host at $PIVOT_EDGE_IP"
}

do_down() {
  rm_container week11_student
  rm_container week11_pivot
  rm_container week11_db
  for n in "$EDGE_NET" "$INTERNAL_NET"; do
    if net_exists "$n"; then
      say "removing network $n"
      podman network rm "$n" >/dev/null 2>&1 || warn "could not remove $n (still in use?)"
    fi
  done
  say "lab is down."
}

do_status() {
  echo "== containers =="
  podman ps -a --filter "name=week11_" \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}' || true
  echo
  echo "== networks =="
  podman network ls --filter "name=week11_" || true
}

do_shell() {
  if ! podman container exists week11_student 2>/dev/null; then
    warn "student container is not running - run ./lab.sh up first"
    exit 1
  fi
  exec podman exec -it week11_student /bin/bash
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
