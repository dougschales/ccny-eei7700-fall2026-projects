# Week 6 lab — script launcher (Ubuntu 22.04 variant)

This is a second variant of the Week 6 lab (network exploitation,
Metasploit Framework, reverse/bind shells, known Linux service CVEs). The
target services and the three-flag set are identical to `../week6/`; the
only difference is **how the containers and networking are brought up**.

| Variant | How it starts | Intended for |
|---|---|---|
| `../week6/` | `podman-compose up` | Modern podman (Fedora, macOS, Windows/WSL2, upgraded Ubuntu) |
| **this one** | `./lab.sh up` | Stock Ubuntu 22.04, **not using podman-compose at all** |

## Why this exists

On stock Ubuntu 22.04 (podman 3.4.4), `podman-compose` silently fails to
attach custom networks (confirmed on prior weeks' labs too). This variant
skips `podman-compose` entirely and drives `podman` directly from a shell
script, the same approach used for `../week5-ubuntu22-script/`.

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

The `student` image is based on `kalilinux/kali-rolling` and installs
`metasploit-framework`, so the first `./lab.sh up` (or `./lab.sh build`)
takes noticeably longer than prior weeks' labs — this is expected.

## Usage

```bash
./lab.sh up        # build images, create the network, start everything
./lab.sh shell     # drop into the student workstation
./lab.sh status    # show container + network state
./lab.sh down      # stop/remove containers and remove the network
./lab.sh rebuild   # down, then up
```

From the student shell, all three targets are directly reachable on the
flat lab network — unlike weeks 4/5, there is no internal-only tier to
pivot through this week. Start with:

```bash
nmap -sV -p- 172.36.0.0/24
```

## Topology (identical to `../week6/`)

```
week6_net 172.36.0.0/24
├─ student       172.36.0.5   (Kali + Metasploit Framework + nmap + searchsploit)
├─ target-ftp    172.36.0.21  (vsftpd 2.3.4 backdoor - emulated, CVE-2011-2523)
├─ target-build  172.36.0.22  (distccd pre-whitelist RCE - emulated, CVE-2004-2687)
└─ target-irc    172.36.0.23  (UnrealIRCd 3.2.8.1 Trojan backdoor - emulated, CVE-2010-2075)
```

## Status

**Smoke-tested on modern podman (netavark, no CNI conflist) on 2026-10-09:
`./lab.sh up` brings up all four containers at their intended static IPs,
and the real `exploit/unix/ftp/vsftpd_234_backdoor` module gets a shell and
reads `/opt/flag1.txt` through it end-to-end.** That exercises the script's
podman invocations and container logic, but not the `patch_cni_version`
branch itself - this sandbox's podman never writes a `cniVersion: 1.0.0`
conflist for `patch_cni_version` to rewrite, so **the actual stock-Ubuntu-
22.04 CNI-version bug path, and the script on real Ubuntu 22.04 hardware,
remain unverified**, following the same pattern as `../week5-ubuntu22-script/`.
