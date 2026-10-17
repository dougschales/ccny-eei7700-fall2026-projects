#!/usr/bin/env bash
#
# Week 7 lab launcher - plain podman, no podman-compose.
#
# Built the same way as ../week6-ubuntu22-script/: stock Ubuntu 22.04
# (podman 3.4.4) has a podman-compose bug where custom networks silently
# fail to attach. Rather than patch a compose-generated CNI config after
# the fact, this script drives podman directly so the compose network
# machinery is never in the picture. The target and student images and
# the five-flag set are identical to ../week7/.
#
# Everything here uses only podman-3.4-safe syntax:
#   - `podman network create --subnet ...`
#   - `podman run --network <name> --ip <addr> --network-alias <name>`
#     (a single network with a static IP is supported on 3.4; the newer
#      `--network name:ip=...,alias=...` form is NOT, so we avoid it)
#
# Usage:
#   ./lab.sh up        build images, create the network, start everything
#   ./lab.sh down       stop/remove containers and remove the network
#   ./lab.sh status    show container + network state
#   ./lab.sh shell      drop into a shell on the student workstation
#   ./lab.sh rebuild    down, then up (force a clean rebuild)

set -euo pipefail

# --- configuration (mirrors ../week7/docker-compose.yml exactly) -----------
NET="week7_net"
SUBNET="172.37.0.0/24"

TARGET_IP="172.37.0.10"
STUDENT_IP="172.37.0.5"

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
  podman build -t week7-target  ./target
  podman build -t week7-student ./student
}

do_up() {
  do_build

  create_net "$NET" "$SUBNET"

  rm_container week7_student
  rm_container week7_target

  say "starting target ($TARGET_IP)"
  podman run -d \
    --name week7_target --hostname target \
    --restart unless-stopped --init \
    --network "$NET" --ip "$TARGET_IP" --network-alias target \
    week7-target >/dev/null

  say "starting student ($STUDENT_IP)"
  podman run -d \
    --name week7_student --hostname student \
    --restart unless-stopped --init \
    --cap-add NET_ADMIN --cap-add NET_RAW \
    -it \
    --network "$NET" --ip "$STUDENT_IP" --network-alias student \
    week7-student >/dev/null

  echo
  say "lab is up. Get a shell on the workstation with:  ./lab.sh shell"
  say "from there: ssh trainee@$TARGET_IP (password: Summer2026!)"
}

do_down() {
  rm_container week7_student
  rm_container week7_target
  if net_exists "$NET"; then
    say "removing network $NET"
    podman network rm "$NET" >/dev/null 2>&1 || warn "could not remove $NET (still in use?)"
  fi
  say "lab is down."
}

do_status() {
  echo "== containers =="
  podman ps -a --filter "name=week7_" \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}' || true
  echo
  echo "== network =="
  podman network ls --filter "name=week7_" || true
}

do_shell() {
  if ! podman container exists week7_student 2>/dev/null; then
    warn "student container is not running - run ./lab.sh up first"
    exit 1
  fi
  exec podman exec -it week7_student /bin/bash
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
