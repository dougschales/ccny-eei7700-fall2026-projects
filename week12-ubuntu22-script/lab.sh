#!/usr/bin/env bash
#
# Week 12 capstone launcher - plain podman, no podman-compose.
#
# Built the same way as ../week5-ubuntu22-script/ and
# ../week11-ubuntu22-script/: stock Ubuntu 22.04 (podman 3.4.4) has a
# podman-compose bug where custom networks silently fail to attach.
# Rather than patch a compose-generated CNI config after the fact, this
# script drives podman directly so the compose network machinery is
# never in the picture. All app code/images are identical to ../week12/.
#
# Everything here uses only podman-3.4-safe syntax:
#   - `podman network create --subnet ...`
#   - `podman run --network <name> --ip <addr> --network-alias <name>`
#     (a single network with a static IP is supported on 3.4; the newer
#      `--network name:ip=...,alias=...` form, and `--ip` on
#      `network connect`, are 4.0+ and NOT available on 3.4.)
#
# DUAL-HOMED HOSTS AND WHICH ADDRESS IS PINNED:
#   build-ci and legacy-svc each need to be reachable from TWO networks,
#   but 3.4 only lets you pin a static --ip on the FIRST network a
#   container joins; the SECOND network (attached after the fact via
#   `podman network connect --alias`, no --ip on 3.4) gets whatever
#   address podman's IPAM assigns.
#
#   - build-ci is started on cap_internal_net FIRST with a pinned IP,
#     because internal-db's own firewall (iptables in its network
#     namespace) only trusts connections from that exact address.
#     cap_edge_net is attached second, unpinned - so build-ci's
#     edge-facing address can vary. Reach it as `build-ci` (podman's
#     embedded DNS), not a memorized IP, for anything from `student`.
#   - legacy-svc is started on cap_core_net FIRST with a pinned IP, for
#     the same reason (core-finance's firewall trusts that exact
#     address). cap_internal_net is attached second, unpinned - reach
#     it as `legacy-svc`, not a memorized IP, when pivoting in from
#     build-ci.
#
# Usage:
#   ./lab.sh up        build images, create the networks, start everything
#   ./lab.sh down       stop/remove containers and remove the networks
#   ./lab.sh status     show container + network state
#   ./lab.sh shell       drop into a shell on the student workstation
#   ./lab.sh rebuild     down, then up (force a clean rebuild)

set -euo pipefail

# --- configuration (mirrors ../week12/docker-compose.yml) -------------------
EDGE_NET="week12_cap_edge_net"
EDGE_SUBNET="172.42.0.0/24"
INTERNAL_NET="week12_cap_internal_net"
INTERNAL_SUBNET="172.42.1.0/24"
CORE_NET="week12_cap_core_net"
CORE_SUBNET="172.42.2.0/24"

EDGE_WEB_IP="172.42.0.10"
BUILD_CI_INTERNAL_IP="172.42.1.11"
INTERNAL_DB_IP="172.42.1.20"
LEGACY_SVC_CORE_IP="172.42.2.30"
CORE_FINANCE_IP="172.42.2.40"
STUDENT_IP="172.42.0.5"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

say() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }

# Same stock-Ubuntu-22.04 CNI cniVersion bug as every prior week's script
# variant - see ../week11-ubuntu22-script/lab.sh for the full writeup.
# Because this script creates each network itself, it can patch the
# conflist BEFORE any container starts - no recreate step needed.
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
  podman build -t week12-edge-web     ./edge-web
  podman build -t week12-build-ci     ./build-ci
  podman build -t week12-internal-db  ./internal-db
  podman build -t week12-legacy-svc   ./legacy-svc
  podman build -t week12-core-finance ./core-finance
  podman build -t week12-student      ./student
}

do_up() {
  do_build

  create_net "$EDGE_NET" "$EDGE_SUBNET"
  create_net "$INTERNAL_NET" "$INTERNAL_SUBNET"
  create_net "$CORE_NET" "$CORE_SUBNET"

  for c in week12_student week12_edge-web week12_build-ci week12_internal-db week12_legacy-svc week12_core-finance; do
    rm_container "$c"
  done

  say "starting edge-web ($EDGE_WEB_IP)"
  podman run -d \
    --name week12_edge-web --hostname edge-web \
    --restart unless-stopped --init \
    --network "$EDGE_NET" --ip "$EDGE_WEB_IP" --network-alias edge-web \
    week12-edge-web >/dev/null

  say "starting internal-db ($INTERNAL_DB_IP, internal-only)"
  podman run -d \
    --name week12_internal-db --hostname internal-db \
    --restart unless-stopped \
    --cap-add NET_ADMIN \
    -e MARIADB_ROOT_PASSWORD="r00t_only_l0cal_2026!" \
    -e MYSQL_DATABASE=ops_ci \
    -e MYSQL_USER=svc_ci \
    -e MYSQL_PASSWORD="CIM3ta_2026!" \
    -e BUILD_CI_INTERNAL_IP="$BUILD_CI_INTERNAL_IP" \
    -v "$SCRIPT_DIR/internal-db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro,Z" \
    --network "$INTERNAL_NET" --ip "$INTERNAL_DB_IP" --network-alias internal-db \
    week12-internal-db >/dev/null

  say "starting core-finance ($CORE_FINANCE_IP, core-only)"
  podman run -d \
    --name week12_core-finance --hostname core-finance \
    --restart unless-stopped \
    --cap-add NET_ADMIN \
    -e MARIADB_ROOT_PASSWORD="r00t_only_l0cal_2026!" \
    -e MYSQL_DATABASE=finance_core \
    -e MYSQL_USER=svc_ledger \
    -e MYSQL_PASSWORD="L3dger_Sync_26!" \
    -e LEGACY_SVC_CORE_IP="$LEGACY_SVC_CORE_IP" \
    -v "$SCRIPT_DIR/core-finance/init.sql:/docker-entrypoint-initdb.d/init.sql:ro,Z" \
    --network "$CORE_NET" --ip "$CORE_FINANCE_IP" --network-alias core-finance \
    week12-core-finance >/dev/null

  say "starting build-ci (internal $BUILD_CI_INTERNAL_IP pinned; edge net attached after, unpinned)"
  podman run -d \
    --name week12_build-ci --hostname build-ci \
    --restart unless-stopped --init \
    --network "$INTERNAL_NET" --ip "$BUILD_CI_INTERNAL_IP" --network-alias build-ci \
    week12-build-ci >/dev/null
  podman network connect --alias build-ci "$EDGE_NET" week12_build-ci

  say "starting legacy-svc (core $LEGACY_SVC_CORE_IP pinned; internal net attached after, unpinned)"
  podman run -d \
    --name week12_legacy-svc --hostname legacy-svc \
    --restart unless-stopped --init \
    --network "$CORE_NET" --ip "$LEGACY_SVC_CORE_IP" --network-alias legacy-svc \
    week12-legacy-svc >/dev/null
  podman network connect --alias legacy-svc "$INTERNAL_NET" week12_legacy-svc

  say "starting student ($STUDENT_IP)"
  podman run -d \
    --name week12_student --hostname student \
    --restart unless-stopped --init \
    --cap-add NET_ADMIN --cap-add NET_RAW \
    -it \
    --network "$EDGE_NET" --ip "$STUDENT_IP" --network-alias student \
    week12-student >/dev/null

  echo
  say "lab is up. Get a shell on the workstation with:  ./lab.sh shell"
  say "start recon against the edge network: curl -s ftp://edge-web/  ;  curl -s http://build-ci:8080/"
  say "build-ci's edge-facing IP and legacy-svc's internal-facing IP are NOT pinned in this"
  say "variant - always reach them by hostname (build-ci / legacy-svc), never a memorized IP."
}

do_down() {
  for c in week12_student week12_edge-web week12_build-ci week12_internal-db week12_legacy-svc week12_core-finance; do
    rm_container "$c"
  done
  for n in "$EDGE_NET" "$INTERNAL_NET" "$CORE_NET"; do
    if net_exists "$n"; then
      say "removing network $n"
      podman network rm "$n" >/dev/null 2>&1 || warn "could not remove $n (still in use?)"
    fi
  done
  say "lab is down."
}

do_status() {
  echo "== containers =="
  podman ps -a --filter "name=week12_" \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}' || true
  echo
  echo "== networks =="
  podman network ls --filter "name=week12_" || true
}

do_shell() {
  if ! podman container exists week12_student 2>/dev/null; then
    warn "student container is not running - run ./lab.sh up first"
    exit 1
  fi
  exec podman exec -it week12_student /bin/bash
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
