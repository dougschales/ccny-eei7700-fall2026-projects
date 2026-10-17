# Week 7 lab — script launcher (Ubuntu 22.04 variant)

This is a second variant of the Week 7 lab (Linux local privilege
escalation). The target image and the five-flag set are identical to
`../week7/`; the only difference is **how the containers and networking
are brought up**.

| Variant | How it starts | Intended for |
|---|---|---|
| `../week7/` | `podman-compose up` | Modern podman (Fedora, macOS, Windows/WSL2, upgraded Ubuntu) |
| **this one** | `./lab.sh up` | Stock Ubuntu 22.04, **not using podman-compose at all** |

## Why this exists

On stock Ubuntu 22.04 (podman 3.4.4), `podman-compose` silently fails to
attach custom networks (confirmed on prior weeks' labs too). This variant
skips `podman-compose` entirely and drives `podman` directly from a shell
script, the same approach used for `../week6-ubuntu22-script/`.

Because the script creates the network itself, it can also patch the
known-bad `cniVersion` (`1.0.0` -> `0.4.0`) in the generated conflist
**before any container starts**, so no recreate step is needed.

## Requirements / compatibility

Written to use only **podman-3.4-safe** syntax, so it runs on stock Ubuntu
22.04 as well as modern podman:

- `podman network create --subnet …`
- `podman run --network <name> --ip <addr> --network-alias <name>` — a
  single network with a static IP (the newer `--network name:ip=…,alias=…`
  form is **4.0+** and is deliberately avoided)

Works rootless or rootful. Rootless is expected on the lab machines (no
sudo); the CNI conflist is then under `~/.config/cni/net.d/`, which the
script checks (it also checks `/etc/cni/net.d/` for rootful).

## Usage

```bash
./lab.sh up        # build images, create the network, start everything
./lab.sh shell     # drop into the student workstation
./lab.sh status    # show container + network state
./lab.sh down      # stop/remove containers and remove the network
./lab.sh rebuild   # down, then up
```

From the student shell, SSH into the target as the low-privileged
account and start enumerating:

```bash
ssh trainee@172.37.0.10   # password: Summer2026!
```

## Topology (identical to `../week7/`)

```
week7_net 172.37.0.0/24
├─ student   172.37.0.5    (ssh client + nmap + basic enumeration tools)
└─ target    172.37.0.10   (low-priv "trainee" account + 4 planted privesc vectors)
```

## The four privilege-escalation vectors on `target`

All four are independent — there is no chain between them, so students
can attempt them in any order. Each confirms itself with its own flag,
stored in a root-owned file named for the vector that unlocks it rather
than a shared `flag_*.txt` directory; finding that file is part of the
exercise. Getting root via any one of them also reveals a final flag
under `/root`. See `../../solutions/README_W7.md` for the student-facing
mission brief and `../../solutions/SOLUTION_W7.md` for the full
instructor walkthrough (including exact flag file paths).

1. **SUID PATH hijack** — `/usr/local/bin/diag` is SUID root and resolves
   `ps` via `$PATH` instead of an absolute path.
2. **Passwordless sudo on `find`** — `sudo -l` shows `NOPASSWD: /usr/bin/find`,
   a classic GTFOBins entry.
3. **A capability on an interpreter** — `/usr/bin/python3.10` carries
   `cap_setuid+ep`.
4. **World-writable root cron script** — `/etc/cron.d/maintenance` runs
   `/opt/maintenance/cleanup.sh` as root every minute, and that script is
   `chmod 777`.

## Status

Smoke-tested on modern podman (netavark, no CNI conflist): `./lab.sh up`
brings up both containers at their intended static IPs, and all four
vectors were exploited end-to-end against this exact image (same image as
`../week7/`, which was verified live — see that project's notes). That
exercises the script's podman invocations and container logic, but not
the `patch_cni_version` branch itself — this sandbox's podman never
writes a `cniVersion: 1.0.0` conflist for `patch_cni_version` to rewrite,
so **the actual stock-Ubuntu-22.04 CNI-version bug path, and the script
on real Ubuntu 22.04 hardware, remain unverified**, following the same
pattern as `../week5-ubuntu22-script/` and `../week6-ubuntu22-script/`.
