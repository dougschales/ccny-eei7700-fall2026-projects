# Week 5 lab — script launcher (Ubuntu 22.04 variant)

This is a **third variant** of the Week 5 lab (LFI/RFI, SSRF, insecure
deserialization). The application code and the five-flag chain are identical to
`../week5/`; the only difference is **how the containers and networking are
brought up**.

| Variant | How it starts | Intended for |
|---|---|---|
| `../week5/` | `podman-compose up` | Modern podman (Fedora, macOS, Windows/WSL2, upgraded Ubuntu) |
| `../week5-ubuntu22/` | `podman-compose up` **+** `fix-ubuntu-networks.sh` | Stock Ubuntu 22.04, patching the compose-generated CNI config after the fact |
| **this one** | `./lab.sh up` | Stock Ubuntu 22.04, **not using podman-compose at all** |

## Why this exists

On stock Ubuntu 22.04 (podman 3.4.4), `podman-compose` silently fails to attach
custom networks. The `week5-ubuntu22` variant works around that by letting
compose generate the networks and then patching the CNI conflist. This variant
takes a different approach: it skips `podman-compose` entirely and drives
`podman` directly from a shell script, so the compose network machinery is never
in the picture.

Because the script creates the networks itself, it can also patch the known-bad
`cniVersion` (`1.0.0` → `0.4.0`) in the generated conflist **before any
container starts**, so no recreate step is needed.

## Requirements / compatibility

Written to use only **podman-3.4-safe** syntax, so it runs on stock Ubuntu 22.04
as well as modern podman:

- `podman network create --subnet …`
- `podman run --network <name> --ip <addr> --network-alias <name>` — a single
  network with a static IP (the newer `--network name:ip=…,alias=…` form and
  `--ip` on `network connect` are **4.0+** and are deliberately avoided)
- `podman network connect --alias <name> <net> <container>` to add the second
  network to the dual-homed `webapp`

Works rootless or rootful. Rootless is expected on the lab machines (no sudo);
the CNI conflist is then under `~/.config/cni/net.d/`, which the script checks
(it also checks `/etc/cni/net.d/` for rootful).

## Usage

```bash
./lab.sh up        # build images, create networks, start everything
./lab.sh shell     # drop into the student workstation
./lab.sh status    # show container + network state
./lab.sh down      # stop/remove containers and remove the networks
./lab.sh rebuild   # down, then up
```

From the student shell, the foothold target is `http://webapp/`. `internal-api`
and `internal-db` are not reachable directly — they sit on the internal network
behind `webapp` and additionally firewall their own namespace to accept only
`webapp`'s internal IP (172.35.1.10).

## Topology (identical to `../week5/`)

```
student (172.35.0.5) ──┐
                       │  week5_edge_net 172.35.0.0/24
       webapp ─────────┤ (172.35.0.10)
         │             │
         │  week5_internal_net 172.35.1.0/24
         ├─ webapp      172.35.1.10
         ├─ internal-api 172.35.1.20  (accepts :8080 only from 172.35.1.10)
         └─ internal-db  172.35.1.30  (accepts :3306 only from 172.35.1.10)
```

## Status

**Not yet verified on a real Ubuntu 22.04 machine.** The syntax choices are
deliberately 3.4-compatible, but whether a direct-podman script actually dodges
the network-attach bug that `podman-compose` hits still needs confirmation on
real hardware. Report back and this note (and the memory) will be updated.
