#!/usr/bin/env bash
#
# fix-ubuntu-networks.sh - workaround for a stock-Ubuntu-22.04-podman bug
# that breaks this lab's network segmentation.
#
# ROOT CAUSE (confirmed by testing the real Ubuntu 22.04 apt packages -
# podman 3.4.4, containernetworking-plugins 0.9.1 - via nested podman):
# podman 3.4.4 writes CNI network config files ("conflists") stamped
# "cniVersion": "1.0.0". Ubuntu 22.04's bundled containernetworking-plugins
# package is capped at 0.9.1 (no newer version is available via apt, even
# from jammy-security/jammy-updates), and its "firewall" plugin rejects
# that version outright:
#   Error validating CNI config file ...: [plugin firewall does not
#   support config version "1.0.0"]
#
# podman does NOT error out when this happens - it silently falls every
# container back onto the single flat default "podman" network instead of
# the compose file's actual week5_edge_net / week5_internal_net networks.
# That defeats this lab's whole premise: internal-api and internal-db are
# supposed to be unreachable from the student workstation directly.
#
# This is a pure version-string mismatch, not a real schema break:
# manually downgrading a generated conflist's cniVersion from 1.0.0 to
# 0.4.0 fixes attachment immediately (confirmed in testing). This script
# automates that, then recreates the CONTAINERS ONLY (never `podman-compose
# down`, which would delete the networks and regenerate a fresh broken
# conflist on the next `up`) so they reattach using the corrected config.
#
# PRIVILEGES: this script never uses sudo and only ever tries to edit
# files it can already write. If you have no privileged access (the normal
# case), you are almost certainly running ROOTLESS podman, which keeps its
# CNI configs under your own $HOME (typically ~/.config/cni/net.d/), not
# under /etc - no root needed to fix it there. This script also checks
# /etc/cni/net.d/ in case you're on rootful podman with a helpful admin;
# if it finds an affected file there it can't write, it says so and does
# not attempt sudo itself.
#
# WHAT'S VERIFIED VS. ASSUMED: the cniVersion bug and the fix for it are
# confirmed. The exact rootless config directory path and the "recreate
# containers without touching the network" recreate step were reasoned
# from podman's documented behavior but could only be directly tested
# against ROOTFUL podman in a nested test rig, not genuine rootless
# Ubuntu 22.04 (nested rootless-in-rootless hit an unrelated
# newuidmap/user-namespace limitation of the test rig itself, not
# something that should occur on a real machine). Please report back
# what this script prints, especially the final network-attachment check.
#
# Usage: run this from the project directory (same one as
# docker-compose.yml), after `podman-compose up -d --build` has already
# been run at least once:
#
#   podman-compose up -d --build
#   ./fix-ubuntu-networks.sh
#
# Or just use `make up`, which runs both steps automatically.

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
        # Only touch conflists that actually belong to this compose project
        # (match by the network's declared "name" field, not just the
        # filename, since naming schemes have varied across podman-compose
        # versions).
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
# docker-compose.yml pins explicit container_name: values (week5_*), not
# project-name-derived ones, so use those literally rather than $PROJECT.
for c in week5_webapp week5_internal-api week5_internal-db week5_student; do
    ip_info=$(podman inspect "$c" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}' 2>/dev/null)
    echo "  $c: ${ip_info:-not found}"
done
echo
echo "[fix-ubuntu-networks] EXPECTED: webapp/internal-api/internal-db/student should show"
echo "[fix-ubuntu-networks] addresses in 172.35.0.x or 172.35.1.x, NOT 10.88.x.x (the default"
echo "[fix-ubuntu-networks] podman network - seeing that means the fix did not take)."
