#!/usr/bin/env bash
#
# fix-ubuntu-networks.sh - workaround for a stock-Ubuntu-22.04-podman bug
# that breaks this lab's network segmentation. Adapted from
# ../week11-ubuntu22/fix-ubuntu-networks.sh for Week 12's project/network
# names - see that script (and ../week5-ubuntu22/) for the full
# root-cause writeup.
#
# ROOT CAUSE (confirmed by testing the real Ubuntu 22.04 apt packages -
# podman 3.4.4, containernetworking-plugins 0.9.1 - via nested podman):
# podman 3.4.4 writes CNI network config files ("conflists") stamped
# "cniVersion": "1.0.0". Ubuntu 22.04's bundled containernetworking-plugins
# package is capped at 0.9.1, and its "firewall" plugin rejects that
# version outright. podman does NOT error out when this happens - it
# silently falls every container back onto the single flat default
# "podman" network instead of this lab's three cap_* networks. That
# defeats this lab's whole premise: internal-db/core-finance are supposed
# to be unreachable except via their one trusted peer, and build-ci/
# legacy-svc are supposed to be dual-homed across two networks each.
#
# This is a pure version-string mismatch, not a real schema break:
# manually downgrading a generated conflist's cniVersion from 1.0.0 to
# 0.4.0 fixes attachment immediately. This script automates that, then
# recreates the CONTAINERS ONLY (never `podman-compose down`, which
# would delete the networks and regenerate a fresh broken conflist on
# the next `up`) so they reattach using the corrected config.
#
# PRIVILEGES: never uses sudo, only ever edits files it can already
# write. Rootless podman (the normal case here) keeps CNI configs under
# $HOME, typically ~/.config/cni/net.d/ - no root needed there. Also
# checks /etc/cni/net.d/ in case of rootful podman; if an affected file
# there can't be written, it says so and does not attempt sudo itself.
#
# WHAT'S VERIFIED VS. ASSUMED: the cniVersion bug and its fix are
# confirmed (see weeks 5/7/8/9/10/11's equivalent scripts). This specific
# script's run against real stock Ubuntu 22.04 hardware is unverified -
# see this directory's README "Status" section.
#
# Usage: run this from the project directory (same one as
# docker-compose.yml), after `podman-compose up -d --build` has already
# been run at least once:
#
#   podman-compose up -d --build
#   ./fix-ubuntu-networks.sh

set -uo pipefail

PROJECT="$(basename "$(pwd)")"
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
for c in week12_edge-web week12_build-ci week12_internal-db week12_legacy-svc week12_core-finance week12_student; do
    ip_info=$(podman inspect "$c" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}' 2>/dev/null)
    echo "  $c: ${ip_info:-not found}"
done
echo
echo "[fix-ubuntu-networks] EXPECTED: build-ci and legacy-svc should each show TWO addresses"
echo "[fix-ubuntu-networks] (172.42.0.x/172.42.1.x for build-ci, 172.42.1.x/172.42.2.x for"
echo "[fix-ubuntu-networks] legacy-svc); internal-db only 172.42.1.x; core-finance only"
echo "[fix-ubuntu-networks] 172.42.2.x; student only 172.42.0.x. Seeing 10.88.x.x anywhere means"
echo "[fix-ubuntu-networks] the fix did not take."
