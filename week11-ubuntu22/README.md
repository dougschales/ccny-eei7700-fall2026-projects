# Week 11 (Ubuntu 22.04 variant)

This is the same lab as `../week11/` (identical app code, identical two
flags, same pivoting chain: leaked backup -> SSH foothold -> blocked
SSH port forward -> chisel reverse SOCKS -> internal database). The
only difference is how you bring it up.

## Why this variant exists

Stock Ubuntu 22.04's podman (`podman 3.4.4` from apt, with
`containernetworking-plugins 0.9.1`, also from apt - no newer version
is available in Ubuntu's repos, including jammy-security/jammy-updates)
has a confirmed bug: it silently fails to attach containers to any
custom compose network. Podman writes network config files stamped
`"cniVersion": "1.0.0"`, but the bundled `firewall` CNI plugin can't
validate that version and rejects it. Instead of erroring, podman falls
every container back onto the single flat default `podman` network -
which means `pivot` would no longer actually be dual-homed and `db`
would end up just as reachable from `student` as `pivot` is, defeating
this lab's whole premise. See `../week5-ubuntu22/README.md` for the
original full writeup of this bug - this is the same fix, adapted for
Week 11's project/network names.

This is a pure version-string mismatch, not a real compatibility
problem: manually downgrading the generated config's `cniVersion` from
`1.0.0` to `0.4.0` fixes attachment immediately. `fix-ubuntu-networks.sh`
automates that.

## How to run this

```
podman-compose up -d --build
./fix-ubuntu-networks.sh
```

The script patches the affected network config file(s) and recreates
the containers (not the networks) so they pick up the fix. It prints
each container's actual network attachment at the end.

**What success looks like:** `pivot` shows addresses on BOTH
`172.41.0.x` and `172.41.1.x`; `db` shows only `172.41.1.x`; `student`
shows only `172.41.0.x`.

**What failure looks like:** any container still shows a `10.88.x.x`
address (the default podman network) - the fix didn't take.

If everything looks right, verify the actual lesson holds - `student`
should NOT be able to reach `db` directly:

```
podman exec week11_student timeout 3 bash -c 'echo > /dev/tcp/172.41.1.20/3306'
# should fail/time out, not connect
```

Then work through the lab exactly as you would `../week11/` - same
recon, same accounts, same flags.

## Status

Smoke-tested on this machine's modern podman (netavark, no CNI
conflist, so `fix-ubuntu-networks.sh` correctly reports nothing to
patch and exits 0) - building the images and bringing the stack up
works, and the full student path (backup leak -> SSH foothold ->
blocked `-D` -> chisel reverse SOCKS -> `db`) was separately verified
end-to-end against `../week11/`'s identical app code (see that
project's notes). That exercises every piece of this variant except
the `cniVersion` patch branch itself and the recreate sequence that
follows it - this sandbox's podman never writes an affected conflist,
so **the actual stock-Ubuntu-22.04 CNI-version bug path, and this
script on real Ubuntu 22.04 hardware, remain unverified**, the same
status as `../week5-ubuntu22/` and `../week10-arm64/`'s siblings. If
you hit something different on real hardware, please report back what
`fix-ubuntu-networks.sh` printed, especially the final network-check
lines.

## If you have to fall back

If the fix script doesn't get you a working segmented network at all,
the lab's core techniques (content discovery, SSH, chisel, proxychains)
still work even on the flat fallback network - you just won't get the
"db is unreachable without pivoting through pivot" part of the lesson,
since everything would already be flatly reachable. Not ideal, but not
a dead end either.
