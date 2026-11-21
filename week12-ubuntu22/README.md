# Week 12 Capstone (Ubuntu 22.04 variant)

This is the same lab as `../week12/` (identical app code, identical ten
flags, same double-pivot capstone chain). The only difference is how you
bring it up.

## Why this variant exists

Stock Ubuntu 22.04's podman (`podman 3.4.4` from apt, with
`containernetworking-plugins 0.9.1`) has a confirmed bug: it silently
fails to attach containers to any custom compose network, falling
everything back onto the flat default `podman` network instead. That
would defeat this lab's whole premise - `internal-db`/`core-finance`
being unreachable except via their one trusted peer, and
`build-ci`/`legacy-svc` being dual-homed. See `../week5-ubuntu22/README.md`
for the full original writeup; `fix-ubuntu-networks.sh` here is the same
fix, adapted for Week 12's three networks and six containers.

## How to run this

```
podman-compose up -d --build
./fix-ubuntu-networks.sh
```

The script patches the affected network config file(s) and recreates
the containers (not the networks) so they pick up the fix. It prints
each container's actual network attachment at the end.

**What success looks like:** `build-ci` shows addresses on both
`172.42.0.x` and `172.42.1.x`; `legacy-svc` shows both `172.42.1.x` and
`172.42.2.x`; `internal-db` only `172.42.1.x`; `core-finance` only
`172.42.2.x`; `edge-web`/`student` only `172.42.0.x`.

**What failure looks like:** any container still shows a `10.88.x.x`
address - the fix didn't take.

Then work through the lab exactly as you would `../week12/` - same
recon, same accounts, same flags. See `../../solutions/README_W12.md`
for the mission objectives and `../../solutions/SOLUTION_W12.md` for the
full walkthrough.

## Status

Smoke-tested on this machine's modern podman (netavark, no CNI conflist,
so `fix-ubuntu-networks.sh` correctly reports nothing to patch and exits
0) - building all six images and bringing the stack up works. The full
ten-flag chain was separately verified end-to-end against `../week12/`'s
identical app code (see that project and `solutions/SOLUTION_W12.md`).
That exercises every piece of this variant except the `cniVersion` patch
branch itself and the recreate sequence that follows it - this sandbox's
podman never writes an affected conflist, so **the actual
stock-Ubuntu-22.04 CNI-version bug path, and this script on real Ubuntu
22.04 hardware, remain unverified**, the same status as every prior
week's `-ubuntu22` sibling.

## If you have to fall back

If the fix script doesn't get you a working segmented network, the
lab's individual techniques (SQLi, LFI, the API chain, SSH, chisel,
proxychains, msf) still work even on the flat fallback network - you
just won't get the network-isolation part of the lesson, since
everything would already be flatly reachable.
