# Week 12 Capstone (Ubuntu 22.04, no-compose variant)

Same lab as `../week12/` - identical app code, identical ten flags - but
driven directly by `podman` instead of `podman-compose`, so the
stock-Ubuntu-22.04 compose network-attach bug (see
`../week5-ubuntu22-script/README.md` for the full root-cause writeup) is
never in the picture.

## How to run this

```
./lab.sh up
./lab.sh shell
```

```
./lab.sh status     # check containers + networks
./lab.sh down        # tear everything down
./lab.sh rebuild      # down, then up
```

## One real difference from the compose variants

Stock Ubuntu 22.04 ships podman 3.4.4, which only supports pinning a
static `--ip` on the *first* network a container joins; a *second*
network attached afterward via `podman network connect` gets whatever
address podman's IPAM assigns, not a chosen one. Both `build-ci` and
`legacy-svc` are dual-homed, and each needs ONE of its two addresses
pinned exactly (because `internal-db`'s and `core-finance`'s own
firewalls trust one specific source address) - so:

- `build-ci`'s **internal-net** address is pinned (`172.42.1.11`); its
  **edge-net** address (what `student` uses to reach it directly) is
  whatever podman assigns.
- `legacy-svc`'s **core-net** address is pinned (`172.42.2.30`); its
  **internal-net** address (what you pivot to from `build-ci`) is
  whatever podman assigns.

**Always reach these two hosts by hostname** (`build-ci`, `legacy-svc` -
podman's embedded DNS resolves them), never by the literal IPs shown in
`solutions/README_W12.md`/`solutions/SOLUTION_W12.md`, which assume the
compose variants' fully-pinned addresses. Everything else (`edge-web`,
`internal-db`, `core-finance`, `student`) has both its address and its
documented IP match exactly, same as the compose variants.

## Status

Smoke-tested on this machine's modern podman (netavark) - `./lab.sh up`
builds all six images, creates all three networks, and starts every
container with the expected topology (`build-ci` and `legacy-svc` each
show two addresses; `internal-db`/`core-finance` show only their one
segment's address). The full ten-flag chain was separately verified
end-to-end against `../week12/`'s identical app code and images (see
that project and `solutions/SOLUTION_W12.md`) - this script exercises
the same images through a different orchestration path, but the
stock-Ubuntu-22.04 CNI-conflist-patch branch itself is **unverified on
real hardware**, same honest caveat as every prior week's equivalent
script variant.
