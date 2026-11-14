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
`run`). The script works around that with a second `podman network
connect --ip <addr> ...` call right after `pivot` starts.

## Requirements / compatibility

Written to use only **podman-3.4-safe** syntax, so it runs on stock Ubuntu
22.04 as well as modern podman:

- `podman network create --subnet …`
- `podman run --network <name> --ip <addr> --network-alias <name>` — a
  single network with a static IP (the newer `--network name:ip=…,alias=…`
  form is **4.0+** and is deliberately avoided)
- `podman network connect --ip <addr> <network> <container>` to attach
  `pivot`'s second interface after it's already running

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

From the student shell, start with recon against the edge-facing host:

```bash
curl -s http://172.41.0.10/robots.txt
```

## Topology (identical to `../week11/`)

```
week11_edge_net 172.41.0.0/24          week11_internal_net 172.41.1.0/24
├─ student   172.41.0.5                                172.41.1.10 ─┤
└─ pivot     172.41.0.10 ── (dual-homed) ── pivot        172.41.1.20 ─ db
```

- **`student`** (`172.41.0.5`): SSH client, chisel, proxychains,
  content-discovery tools, `mysql` client. Only on the edge network.
- **`pivot`** (`172.41.0.10` / `172.41.1.10`): the compromised
  edge web server. Dual-homed on purpose - reachable from `student`
  directly, and able to reach `db` on the internal network. Leaks SSH
  credentials via its own docroot and carries a leftover admin tool
  worth finding.
- **`db`** (`172.41.1.20`): internal-only MariaDB, firewalled (inside
  its own container, not the host) to accept connections only from
  `pivot`'s internal IP.

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
