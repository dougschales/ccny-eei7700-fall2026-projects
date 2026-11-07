# Week 10 lab — script launcher (Ubuntu 22.04 variant)

This is a second variant of the Week 10 lab (binaries and buffer
overflows). The target image and the flag set are identical to
`../week10/`; the only difference is **how the containers and
networking are brought up**.

| Variant | How it starts | Intended for |
|---|---|---|
| `../week10/` | `podman-compose up` | Modern podman (Fedora, macOS, Windows/WSL2, upgraded Ubuntu) |
| **this one** | `./lab.sh up` | Stock Ubuntu 22.04, **not using podman-compose at all** |

## Why this exists

On stock Ubuntu 22.04 (podman 3.4.4), `podman-compose` silently fails to
attach custom networks (confirmed on prior weeks' labs too). This variant
skips `podman-compose` entirely and drives `podman` directly from a shell
script, the same approach used for `../week7-ubuntu22-script/`.

Because the script creates the network itself, it can also patch the
known-bad `cniVersion` (`1.0.0` -> `0.4.0`) in the generated conflist
**before any container starts**, so no recreate step is needed.

The target container is started with `--security-opt seccomp=unconfined`
(see `target/entrypoint.sh`) because default seccomp profiles block the
`personality(2)` syscall, which both overflow targets need (via
`setarch -R`) to disable ASLR for themselves.

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

From the student shell, recon the target:

```bash
nmap -p- 172.40.0.10          # docs portal on 80, statusd on 7777
```

## Topology (identical to `../week10/`)

```
week10_net 172.40.0.0/24
├─ student   172.40.0.5    (gdb, gcc, pwntools, nmap, netcat)
└─ target    172.40.0.10   (docs portal :80, statusd :7777, diagtool via cron)
```

## The chain on `target`

1. **LFI document leak** (same bug class as Week 5) — the docs portal's
   `/docs/view?file=` is vulnerable to path traversal, and the non-linked
   `/opt/app/internal/releases/` directory holds the exact `statusd`
   binary and its `.c` source running on TCP/7777.
2. **Remote stack overflow in `statusd`** — a classic, unmitigated
   (`-fno-stack-protector -no-pie -z execstack`, ASLR disabled via
   `setarch -R`) stack smash gets a shell as the low-privileged `svc`
   account.
3. **Local privilege escalation via `diagtool`** — the same bug shape,
   this time triggered once a minute by a root cron job against
   `/var/spool/fleet/pending.dat`, a file `svc` can write to. Landing
   shellcode there runs as root.

Each step confirms itself with its own flag, stored in a file named for
the step that unlocks it rather than a shared `flag_*.txt` directory;
finding that file is part of the exercise. See
`../../solutions/README_W10.md` for the student-facing mission brief and
`../../solutions/SOLUTION_W10.md` for the full instructor walkthrough
(including exact offsets and addresses).

## Status

Smoke-tested on modern podman (netavark, no CNI conflist): `./lab.sh up`
brings up both containers at their intended static IPs, and the full
chain (LFI leak, remote overflow, cron-triggered local overflow, root)
was exploited end-to-end against this exact image. That exercises the
script's podman invocations and container logic, but not the
`patch_cni_version` branch itself — this sandbox's podman never writes a
`cniVersion: 1.0.0` conflist for `patch_cni_version` to rewrite, so **the
actual stock-Ubuntu-22.04 CNI-version bug path, and the script on real
Ubuntu 22.04 hardware, remain unverified**, following the same pattern as
`../week5-ubuntu22-script/`, `../week6-ubuntu22-script/`, and
`../week7-ubuntu22-script/`.
