# Week 10 lab — Apple Silicon (arm64) variant

This is the Apple Silicon variant of the Week 10 lab (binaries and
buffer overflows). It is identical to `../week10/` in every respect
except that both images are pinned to `platform: linux/arm64`, so podman
builds and runs them *natively* on an M-series Mac's own CPU — there is
no QEMU emulation involved.

| Variant | Platform pin | Intended for |
|---|---|---|
| `../week10/` | `linux/amd64` | Intel/AMD Linux, Windows/WSL2, Intel Macs |
| **this one** | `linux/arm64` | Apple Silicon Macs (podman machine is already arm64 there) |
| `../week10-ubuntu22-script/` | `linux/amd64` | Stock Ubuntu 22.04 (old podman-compose bug) |

## Why a separate variant at all

`statusd` and `diagtool` are compiled from source **inside** the target
container at startup (see `target/entrypoint.sh`), so they are always
native binaries for whatever CPU podman is actually running on — in
that sense a single project would "just work" on either architecture
without any of this. What does *not* carry over between architectures
is the exploit itself: register names, the calling convention, where
the return address lives relative to the stack frame, and the shellcode
bytes are all different between x86_64 and aarch64. Pinning the
platform explicitly, rather than letting it float with whatever host
podman happens to run on, keeps the numbers in the solution guide
deterministic for whichever track a student is on.

## What's different about exploiting this build (aarch64)

- **No single "return address on the stack" pop.** AArch64 functions
  save the frame pointer and link register together on entry
  (`stp x29, x30, [sp, -16]!`) and restore them on exit
  (`ldp x29, x30, [sp], 16`) before `ret`, which jumps to whatever is in
  the **x30** register at that point — not literally "pop and jump" the
  way x86_64's `ret` is. The overflow technique is the same idea (walk
  past the buffer until you reach the saved x30 slot and overwrite it),
  the offset arithmetic is just against x29/x30's save slot instead of
  a pushed return address.
- **4-byte instruction alignment.** ARM64 instructions are always 4
  bytes, and a branch to a misaligned address raises SIGBUS instead of
  running your shellcode. Check that your jump target is 4-byte
  aligned (it should be, since the stack frame itself is 16-byte
  aligned at function entry per AAPCS64 — but verify it with `gdb`
  rather than assuming).
- **Different shellcode, same pwntools workflow.** `context.arch =
  'aarch64'` and `shellcraft.aarch64.linux.sh()` /
  `shellcraft.aarch64.linux.execve(...)` replace the amd64 versions;
  the rest of the exploit-building workflow (`asm()`, `cyclic()`,
  `p64()` for the 64-bit address) is identical.
- **Same mitigations, same disabling flags.** `-fno-stack-protector`,
  `-no-pie`, and `-z execstack` all mean exactly what they mean on
  x86_64, and `setarch <arch> -R` still disables ASLR per-process via
  the same `personality(2)` syscall — it's architecture-independent.
- **The stack-collision pitfall from the x86_64 track still applies.**
  Shellcode that lives on the stack and also *uses* the stack (pushing
  strings to build an argv array, for example) can overwrite its own
  not-yet-executed tail if it doesn't leave itself enough room below
  where it starts running. The x86_64 track's fix — a short stub that
  moves the stack pointer well out of the way before the real shellcode
  runs — is the same fix here, just assembled for aarch64 (e.g. `sub
  sp, sp, #0x1000` in place of `sub rsp, 0x1000`).

## Status — unverified on real hardware

This sandbox is x86_64 with no `qemu-user-static`/binfmt registration
available (confirmed: `podman build --platform linux/arm64` fails
immediately with `exec container process: Exec format error` the
moment the build tries to run `apt-get` under emulation), so **this
variant has not been built, run, or exploited end-to-end** the way
`../week10/` and `../week10-ubuntu22-script/` were. Everything here is
carried over unchanged from the verified x86_64 build plus the
general-knowledge aarch64 notes above — the actual stack offsets and
addresses for this track need to be determined fresh on real Apple
Silicon hardware using the exact same `gdb`/`cyclic` methodology
described in `../../solutions/SOLUTION_W10.md`, not assumed from the
x86_64 numbers. Treat this the same way as any other
hardware-dependent variant in this repo that's shipped ahead of a real
test pass.
