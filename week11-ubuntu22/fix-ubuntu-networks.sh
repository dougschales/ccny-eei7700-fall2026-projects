#!/usr/bin/env bash
#
# fix-ubuntu-networks.sh - workaround for a stock-Ubuntu-22.04-podman bug
# that breaks this lab's network segmentation. Adapted from
# ../week5-ubuntu22/fix-ubuntu-networks.sh for Week 11's project/network
# names - see that script for the full root-cause writeup.
#
# ROOT CAUSE (confirmed by testing the real Ubuntu 22.04 apt packages -
# podman 3.4.4, containernetworking-plugins 0.9.1 - via nested podman):
# podman 3.4.4 writes CNI network config files ("conflists") stamped
# "cniVersion": "1.0.0". Ubuntu 22.04's bundled containernetworking-plugins
# package is capped at 0.9.1, and its "firewall" plugin rejects that
# version outright. podman does NOT error out when this happens - it
# silently falls every container back onto the single flat default
# "podman" network instead of week11_edge_net / week11_internal_net.
# That defeats this lab's whole premise: db is supposed to be
# unreachable from the student workstation directly, and pivot is
# supposed to be dual-homed onto two separate networks.
#
# This is a pure version-string mismatch, not a real schema break:
# manually downgrading a generated conflist's cniVersion from 1.0.0 to
# 0.4.0 fixes attachment immediately. This script automates that, then
# recreates the CONTAINERS ONLY (never `podman-compose down`, which
# would delete the networks and regenerate a fresh broken conflist on
# the next `up`) so they reattach using the corrected config.
#
# PRIVILEGES: this script never uses sudo and only ever tries to edit
# files it can already write. Rootless podman (the normal case here)
# keeps its CNI configs under your own $HOME, typically
# ~/.config/cni/net.d/ - no root needed to fix it there. This script
# also checks /etc/cni/net.d/ in case you're on rootful podman; if it
# finds an affected file there it can't write, it says so and does not
# attempt sudo itself.
#
# WHAT'S VERIFIED VS. ASSUMED: the cniVersion bug and its fix are
# confirmed (see week5/week7/week10's equivalent scripts, all tested the
# same way). The exact rootless config directory path and the
# "recreate containers without touching the network" step were reasoned
# from podman's documented behavior and this script's own structure
# mirrors those already-tested ones, but this specific script's run
# against real stock Ubuntu 22.04 hardware is unverified - see this
# directory's README "Status" section.
#
# Usage: run this from the project directory (same one as
# docker-compose.yml), after `podman-compose up -d --build` has already
# been run at least once:
#
#   podman-compose up -d --build
#   ./fix-ubuntu-networks.sh

set -uo pipefail

PROJECT="$(basename "$(pwd)")"
# podman-compose normalizes the project name (lowercases it, strips
# anything not [a-z0-9_.-]) when building network names - match that here
# so we actually find the right conflist files.
PROJECT_NORM="$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_.-' '_')"

CANDIDATE_DIRS=(
    "/etc/cni/net.d"
    "${XDG_CONFIG_HOME:-$HOME/.config}/cni/net.d"
)

echo "[fix-ubuntu-networks] Project name (normalized): $PROJECT_NORM"
echo "[fix-ubuntu-networks] Looking for this project's CNI network configs..."

found_any=0
patched_any=0
denied_any=0

for dir in "${CANDIDATE_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    for conflist in "$dir"/*.conflist; do
        [ -e "$conflist" ] || continue
        if ! grep -q "\"name\": *\"${PROJECT_NORM}_" "$conflist" 2>/dev/null; then
            continue
        fi
        found_any=1
        echo "[fix-ubuntu-networks] Found project network config: $conflist"
        if grep -q '"cniVersion": *"1\.0\.0"' "$conflist" 2>/dev/null; then
            if sed -i 's/"cniVersion": *"1\.0\.0"/"cniVersion": "0.4.0"/' "$conflist" 2>/dev/null; then
                echo "[fix-ubuntu-networks]   -> patched cniVersion 1.0.0 -> 0.4.0"
                patched_any=1
            else
                echo "[fix-ubuntu-networks]   -> COULD NOT WRITE (permission denied)."
                echo "[fix-ubuntu-networks]      This file is under $dir - if that's /etc/cni/net.d,"
                echo "[fix-ubuntu-networks]      you're on rootful podman; ask whoever has root on"
                echo "[fix-ubuntu-networks]      this machine to run: sudo $0"
                denied_any=1
            fi
        else
            echo "[fix-ubuntu-networks]   -> already looks fine (not stamped 1.0.0), leaving it alone."
        fi
    done
done

if [ "$found_any" -eq 0 ]; then
    echo "[fix-ubuntu-networks] No CNI config files found for project '$PROJECT_NORM' in:"
    for dir in "${CANDIDATE_DIRS[@]}"; do echo "  $dir"; done
    echo "[fix-ubuntu-networks] Either 'podman-compose up' hasn't been run yet, or this podman is"
    echo "[fix-ubuntu-networks] using netavark instead of CNI (podman info | grep -i network) - in"
    echo "[fix-ubuntu-networks] which case this specific bug doesn't apply and there's nothing to do."
    exit 0
fi

if [ "$denied_any" -eq 1 ] && [ "$patched_any" -eq 0 ]; then
    echo "[fix-ubuntu-networks] Found affected files but couldn't write any of them. See above."
    exit 1
fi

if [ "$patched_any" -eq 0 ]; then
    echo "[fix-ubuntu-networks] Nothing needed patching."
    exit 0
fi

echo "[fix-ubuntu-networks] Recreating containers (NOT the networks) so they pick up the fix..."
podman-compose stop
podman-compose rm -f
podman-compose up -d

echo
echo "[fix-ubuntu-networks] Done. Checking actual container network attachment:"
for c in week11_pivot week11_db week11_student; do
    ip_info=$(podman inspect "$c" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}' 2>/dev/null)
    echo "  $c: ${ip_info:-not found}"
done
echo
echo "[fix-ubuntu-networks] EXPECTED: pivot should show BOTH a 172.41.0.x and a"
echo "[fix-ubuntu-networks] 172.41.1.x address; db should show only 172.41.1.x; student only"
echo "[fix-ubuntu-networks] 172.41.0.x. Seeing 10.88.x.x anywhere means the fix did not take."
