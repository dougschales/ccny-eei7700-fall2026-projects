# Week 5 (Ubuntu 22.04 variant)

This is the same lab as `../week5/` (identical app code, same 5 flags,
same vulnerability classes - LFI/RFI, SSRF, insecure deserialization).
The only difference is how you bring it up.

## Why this variant exists

Stock Ubuntu 22.04's podman (`podman 3.4.4` from apt, with
`containernetworking-plugins 0.9.1` - also from apt, and there is no
newer version available in Ubuntu's repos, checked including
jammy-security/jammy-updates) has a confirmed bug: it silently fails to
attach containers to any custom compose network, `internal: true` or not.
Podman writes network config files stamped `"cniVersion": "1.0.0"`, but
the bundled `firewall` CNI plugin can't validate that version and rejects
it. Instead of erroring, podman falls every container back onto the
single flat default `podman` network - which means `internal-api` and
`internal-db` end up just as reachable from the student workstation as
`webapp` is, defeating the whole point of this lab (and, we discovered
while investigating this, Week 4's as well - that's a separate,
still-open issue in `../week4/`, not something this variant touches).

This is a pure version-string mismatch, not a real compatibility problem:
manually downgrading the generated config's `cniVersion` from `1.0.0` to
`0.4.0` fixes attachment immediately. `fix-ubuntu-networks.sh` automates
that.

## How to run this

```
podman-compose up -d --build
./fix-ubuntu-networks.sh
```

The script patches the affected network config file(s) and recreates the
containers (not the networks - recreating those would just regenerate the
same broken config) so they pick up the fix. It prints each container's
actual network attachment at the end.

**What success looks like:** `webapp`, `internal-api`, `internal-db`, and
`student` should show addresses on `172.35.0.x` or `172.35.1.x`.

**What failure looks like:** any container still shows a `10.88.x.x`
address (the default podman network) - the fix didn't take. See
"Known gaps" below.

If everything looks right, verify the actual lesson holds - `student`
should NOT be able to reach `internal-api` or `internal-db` directly:

```
podman exec week5_student curl -s --max-time 4 http://172.35.1.20:8080/
# should time out / fail to connect, not return a response
```

Then work through the lab exactly as you would `../week5/` - same routes,
same flags.

## Known gaps - please report back on these

This variant was built and reasoned through carefully, but **the network
fix itself has not been verified end-to-end on a real Ubuntu 22.04
machine** - only the underlying bug and the raw fix mechanism were
confirmed (via nested podman, using the real Ubuntu 22.04 packages, but
running as root/rootful rather than the normal no-privileged-access
rootless setup). Specifically unverified:

1. **The CNI config directory path.** The script checks both
   `/etc/cni/net.d/` (rootful) and `${XDG_CONFIG_HOME:-$HOME/.config}/cni/net.d/`
   (rootless - the expected case with no sudo access), but this exact path
   wasn't directly confirmed on genuine rootless Ubuntu 22.04.
2. **That `podman-compose stop && podman-compose rm -f && podman-compose up -d`
   preserves the patched network** instead of regenerating a fresh broken
   one. This was reasoned from compose semantics (`rm` removes containers
   only, not networks) but not directly tested in that exact sequence.

If `fix-ubuntu-networks.sh` says "No CNI config files found" but things
still don't work, or the final network check still shows `10.88.x.x`
addresses, please capture and send back:

```
podman-compose --version
podman --version
podman network ls
find /etc/cni/net.d "${XDG_CONFIG_HOME:-$HOME/.config}/cni/net.d" -name '*.conflist' 2>/dev/null
podman inspect week5_webapp --format '{{json .NetworkSettings.Networks}}'
```

That's enough to pin down exactly what differs from what was tested here
and fix the script for real, rather than guessing again.

## If you have to fall back

If the fix script doesn't get you a working segmented network at all, the
lab's core teaching content (LFI, SSRF, insecure deserialization as
*techniques*) still works even on the flat fallback network - you just
won't get the "internal-api/internal-db are unreachable without pivoting
through webapp" part of the lesson, since everything is already flatly
reachable. Not ideal, but not a dead end either.
