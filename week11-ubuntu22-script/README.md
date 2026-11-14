# Week 11 lab - script launcher (Ubuntu 22.04 variant)

This is a second variant of the Week 11 lab (Post-Exploitation &
Pivoting). The pivot/db images and both flags are identical to
`../week11/`; the only difference is **how the containers and
networking are brought up**.

| Variant | How it starts | Intended for |
|---|---|---|
| `../week11/` | `podman-compose up` | Modern podman (Fedora, macOS, Windows/WSL2, upgraded Ubuntu) |
| **this one** | `./lab.sh up` | Stock Ubuntu 22.04, **not using podman-compose at all** |

## Why this exists

On stock Ubuntu 22.04 (podman 3.4.4), `podman-compose` silently fails to
attach custom networks (confirmed on prior weeks' labs too). This variant
skips `podman-compose` entirely and drives `podman` directly from a shell
script, the same approach used for `../week7-ubuntu22-script/`.

Because the script creates the networks itself, it can also patch the
known-bad `cniVersion` (`1.0.0` -> `0.4.0`) in the generated conflist
**before any container starts**, so no recreate step is needed.

This lab also needs `pivot` dual-homed onto two separate networks, which
`podman run` on 3.4 can't do in one shot (only one `--network` flag per
`run`). The script works around that the same way `../week5-ubuntu22-script/`
does for its own dual-homed `webapp`: `pivot` is started on the internal
network first with a pinned `--ip` (the address `db`'s firewall actually
checks), then the edge network is attached afterward with a plain
`podman network connect --alias pivot` - **no `--ip`**, since that flag on
`network connect` is a 4.0+ addition and podman 3.4 rejects it outright
("--ip is not a valid option"). That means `pivot`'s edge-facing address
isn't guaranteed to be `172.41.0.10` on this variant; `student` reaches it
by the `pivot` network alias (podman's embedded DNS) instead.

## Requirements / compatibility

Written to use only **podman-3.4-safe** syntax, so it runs on stock Ubuntu
22.04 as well as modern podman:

- `podman network create --subnet …`
- `podman run --network <name> --ip <addr> --network-alias <name>` — a
  single network with a static IP (the newer `--network name:ip=…,alias=…`
  form is **4.0+** and is deliberately avoided)
- `podman network connect --alias <name> <network> <container>` to attach
  `pivot`'s second interface after it's already running (no `--ip` - not
  available on 3.4)

Works rootless or rootful. Rootless is expected on the lab machines (no
sudo); the CNI conflist is then under `~/.config/cni/net.d/`, which the
script checks (it also checks `/etc/cni/net.d/` for rootful).

## Usage

```bash
./lab.sh up        # build images, create both networks, start everything
./lab.sh shell     # drop into the student workstation
./lab.sh status    # show container + network state
./lab.sh down      # stop/remove containers and remove both networks
./lab.sh rebuild   # down, then up
```

From the student shell, start with recon against the edge-facing host -
use the `pivot` hostname, not a literal edge IP (see below for why):

```bash
curl -s http://pivot/robots.txt
```

## Topology (same as `../week11/`, except `pivot`'s edge address)

```
week11_edge_net 172.41.0.0/24          week11_internal_net 172.41.1.0/24
├─ student   172.41.0.5                                172.41.1.10 ─┤
└─ pivot     (podman-assigned) ── (dual-homed) ── pivot  172.41.1.20 ─ db
```

- **`student`** (`172.41.0.5`): SSH client, chisel, proxychains,
  content-discovery tools, `mysql` client. Only on the edge network.
- **`pivot`** (edge: whatever podman's IPAM assigns - reach it as
  `pivot`; internal: pinned at `172.41.1.10`, since that's the address
  `db`'s own firewall checks): the compromised edge web server.
  Dual-homed on purpose - reachable from `student` directly, and able
  to reach `db` on the internal network. Leaks SSH credentials via its
  own docroot and carries a leftover admin tool worth finding.
- **`db`** (`172.41.1.20`): internal-only MariaDB, firewalled (inside
  its own container, not the host) to accept connections only from
  `pivot`'s internal IP.

**Why `pivot`'s edge IP isn't pinned here:** unlike `../week11/` and
`../week11-ubuntu22/` (both podman-compose, which can pin both of a
container's network addresses in one definition), this script has to
attach `pivot`'s two networks with two separate CLI calls, and only the
first one (`podman run --ip`) supports a static address on podman 3.4.
The second (`podman network connect`) does not take `--ip` until
podman 4.0. So `pivot` is pinned on the network where it actually
matters - `db`'s firewall allowlists one exact source address - and
left to float on the edge network, where nothing cares about the exact
value as long as the `pivot` alias resolves to it.

## The pivoting chain

Both flags, and every technique in between (content discovery, SSH,
a deliberately blocked SSH tunnel, chisel, proxychains), are identical
to `../week11/` - see `../../solutions/README_W11.md` for the
student-facing mission brief and `../../solutions/SOLUTION_W11.md` for
the full instructor walkthrough.

## Status

Verified end-to-end on this machine's podman (netavark, no CNI
conflist to patch): `./lab.sh up` brings up all three containers with
`pivot` correctly dual-homed on both networks, `db` is unreachable
directly from `student`, and the complete student path was run for
real, entirely from inside `student` over the network (recon ->
`ffuf` finds the backup -> leaked SSH creds -> foothold flag -> `ssh -D`
confirmed blocked with "administratively prohibited" -> chisel found
on `pivot` -> reverse SOCKS tunnel established -> `proxychains` +
`mysql` reach `db` -> second flag retrieved). That exercises every
piece of this script except the `patch_cni_version` branch itself -
this sandbox's podman never writes a `cniVersion: 1.0.0` conflist for
it to rewrite, so **the actual stock-Ubuntu-22.04 CNI-version bug path,
and this script on real Ubuntu 22.04 hardware, remain unverified**,
the same status as `../week5-ubuntu22-script/`, `../week6-ubuntu22-script/`,
`../week7-ubuntu22-script/`, and `../week10-ubuntu22-script/`.
