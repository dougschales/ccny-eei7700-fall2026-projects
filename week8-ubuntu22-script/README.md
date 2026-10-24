# Week 8 lab — script launcher (Ubuntu 22.04 variant)

This is a second variant of the Week 8 lab (password cracking &
credential harvesting). The target image and flag set are identical to
`../week8/`; the only difference is **how the containers and networking
are brought up**.

| Variant | How it starts | Intended for |
|---|---|---|
| `../week8/` | `podman-compose up` | Modern podman (Fedora, macOS, Windows/WSL2, upgraded Ubuntu) |
| **this one** | `./lab.sh up` | Stock Ubuntu 22.04, **not using podman-compose at all** |

## Why this exists

On stock Ubuntu 22.04 (podman 3.4.4), `podman-compose` silently fails to
attach custom networks (confirmed on prior weeks' labs too). This variant
skips `podman-compose` entirely and drives `podman` directly from a shell
script, the same approach used for `../week7-ubuntu22-script/`.

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

From the student shell, the account on `target` is `trainee` - but unlike
previous weeks, **no password is given**. See
`../../solutions/README_W8.md` for the student-facing mission brief and
`../../solutions/SOLUTION_W8.md` for the full instructor walkthrough.

## Topology (identical to `../week8/`)

```
week8_net 172.38.0.0/24
├─ student   172.38.0.5    (ssh client + hydra + john + hashcat)
└─ target    172.38.0.10   ("trainee" SSH foothold + 3 planted credential-harvesting vectors)
```

## The credential-harvesting vectors on `target`

All three are independent - there is no chain between them, so students
can attempt them in any order once they have the SSH foothold. Each
confirms itself with its own flag, stored in a file owned by the account
whose credential unlocks it. Successfully harvesting the third vector's
credential also unlocks a final flag via a narrowly-scoped sudo rule.

1. **Online brute force (foothold)** — the `trainee` account's SSH
   password isn't given; it's one entry in the shared wordlist, crackable
   with Hydra.
2. **A forgotten shadow backup** — a world-readable backup file contains
   a real SHA-512 crypt (`$6$`) hash, crackable with John the Ripper.
3. **A leftover application database export** — a CSV with bcrypt
   password hashes, including one decoy that won't crack with the
   provided wordlist.
4. **A forgotten, encrypted SSH private key** — passphrase-protected,
   crackable only by trying the wordlist against it directly (no
   dedicated tool needed beyond `ssh-keygen`).

## A note on Hashcat

Hashcat is installed on the student image per the syllabus, but its
OpenCL backend depends on a CPU runtime (`pocl`) that has a known kernel
build failure (`unknown target CPU 'generic'`) on some host CPUs when
running inside a container with no GPU passthrough. It may work on your
machine - it isn't required to: every vector in this lab is solvable with
John the Ripper and Hydra alone, which have no such dependency.

## Status

Built and verified end-to-end in this sandbox using only the
student-facing commands (slide deck + `../../solutions/README_W8.md`),
not the instructor solution's shortcuts. That surfaced and fixed three
real bugs, since corrected in `target/entrypoint.sh` and the
student-facing docs:

- **Target wasn't restart-safe.** `entrypoint.sh` ran under `set -e` with
  non-idempotent `useradd` calls and no guard - since the compose file
  sets `restart: unless-stopped`, any crash, reboot, or manual restart
  re-ran the script against the same already-provisioned container,
  `useradd` failed immediately, and sshd never came back up. The target
  would crash-loop forever until someone noticed and fully rebuilt it.
  Fixed with a `/opt/.week8_provisioned` marker: a restart now skips
  straight to restarting sshd.
- **John can't parse the discovered CSV as-is.** `find / -iname "*.csv"`
  turns up `users_backup.csv`, which is comma-delimited with a header
  row - `john --format=bcrypt` on it directly reports "No password
  hashes loaded." Students need to strip the header and extract the hash
  column first (`tail -n +2 ... | awk -F, '{print $2}'`); this step was
  missing from both the slide deck's Examples slide and
  `../../solutions/README_W8.md` and has been added to both.
- **`ssh-keygen -y` silently refuses the copied private key.** `scp`
  lands the key at mode 644, and `ssh-keygen` won't even attempt
  decryption against a group/other-readable key file - it fails with
  "bad permissions" regardless of whether the passphrase guess is
  correct. The documented brute-force loop redirects all output to
  `/dev/null`, so this produced zero output across the entire wordlist
  with no indication of what went wrong. Fixed by adding `chmod 600` to
  the key before the loop, in the slide deck, the Hints slide, and
  `../../solutions/README_W8.md`.

With those fixes, all 5 flags were confirmed reachable using exactly the
commands given to students (not the instructor-only shortcuts). This
exercises the target image and both students' tool flows directly (same
image as `../week8/`), but not this script's own podman invocations or
the `patch_cni_version` branch - this sandbox's podman never writes a
`cniVersion: 1.0.0` conflist for that branch to patch, so **the actual
stock-Ubuntu-22.04 CNI-version bug path, and this script on real
Ubuntu 22.04 hardware, remain unverified**, following the same pattern as
`../week5-ubuntu22-script/`, `../week6-ubuntu22-script/`, and
`../week7-ubuntu22-script/`.
