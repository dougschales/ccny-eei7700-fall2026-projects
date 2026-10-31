# Week 9 lab — script launcher (Ubuntu 22.04 variant)

This is a second variant of the Week 9 lab (API Security & Business Logic
Flaws). The target image and the flag set are identical to `../week9/`;
the only difference is **how the containers and networking are brought
up**.

| Variant | How it starts | Intended for |
|---|---|---|
| `../week9/` | `podman-compose up` | Modern podman (Fedora, macOS, Windows/WSL2, upgraded Ubuntu) |
| **this one** | `./lab.sh up` | Stock Ubuntu 22.04, **not using podman-compose at all** |

## Why this exists

On stock Ubuntu 22.04 (podman 3.4.4), `podman-compose` silently fails to
attach custom networks (confirmed on prior weeks' labs too). This variant
skips `podman-compose` entirely and drives `podman` directly from a shell
script, the same approach used for `../week7-ubuntu22-script/` and
`../week8-ubuntu22-script/`.

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

From the student shell, start by exploring the HelpDesk API - there is no
SSH account handed out this week:

```bash
curl -s http://172.39.0.10:8080/ | jq .
```

## Topology (identical to `../week9/`)

```
week9_net 172.39.0.0/24
├─ student   172.39.0.5    (curl/jq + john + ssh client, no exploit framework)
└─ target    172.39.0.10   (HelpDesk API on :8080, sshd on :22, no password login)
```

## The chain on `target`

Unlike Week 7 (four independent vectors), this week is a single chain -
each stage unlocks the next:

1. **API endpoint discovery** — the unauthenticated `/api/openapi.json`
   spec lists admin-only routes that are never linked anywhere else.
2. **BOLA / IDOR** — `GET /api/tickets/<id>` never checks that the
   ticket's `owner_id` matches the caller; incrementing past your own
   ticket IDs reads another employee's ticket, which references an
   archived SSH private key attachment.
3. **Mass assignment → role escalation** — `PATCH /api/users/me` merges
   every field you send with no allow-list, so sending `{"role": "admin"}`
   escalates your own account.
4. **Broken function-level authorization** — with the forged admin role,
   `GET /api/tickets/<id>/attachment` and `GET /api/admin/users` (both
   correctly role-gated, but trusting the role the previous bug let you
   forge) are now reachable, and the attachment download hands you the
   passphrase-protected private key.
5. **Passphrase crack (Week 8 technique)** — the key's passphrase is in
   the shared wordlist; the same `ssh-keygen -y -f <key> -P` loop from
   Week 8 recovers it.
6. **Sudo misconfiguration (Week 7 technique, new binary)** — the
   decrypted key logs in as `opskey`, whose `sudo -l` shows a different
   GTFOBins entry (`tar`, not `find`) for the final root flag.

See `../../solutions/README_W9.md` for the student-facing mission brief
and `../../solutions/SOLUTION_W9.md` for the full instructor walkthrough
(including exact flag file paths).

## Status

Smoke-tested on modern podman (netavark, no CNI conflist): `./lab.sh up`
brings up both containers at their intended static IPs, and the full
chain (API discovery -> BOLA -> mass assignment -> attachment download ->
passphrase crack -> SSH -> sudo tar -> root) was exploited end-to-end
against this exact image (same image as `../week9/`). That exercises the
script's podman invocations and container logic, but not the
`patch_cni_version` branch itself — this sandbox's podman never writes a
`cniVersion: 1.0.0` conflist for `patch_cni_version` to rewrite, so **the
actual stock-Ubuntu-22.04 CNI-version bug path, and the script on real
Ubuntu 22.04 hardware, remain unverified**, following the same pattern as
`../week5-ubuntu22-script/`, `../week6-ubuntu22-script/`, and
`../week7-ubuntu22-script/`.
