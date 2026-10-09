#!/usr/bin/env python3
"""Minimal distcc server reproducing CVE-2004-2687, pre-whitelist.

distcc's wire protocol lets a client submit a "compile job" as an argv
array plus a preprocessed source file; the daemon reconstructs a single
command line from argv and runs it. The original (2004-era) distccd
imposed no restriction on what that reconstructed command line could be
- if the client's argv[0] itself contained a full shell command (with a
trailing '#' to comment out the compiler-looking arguments distcc
appends), the daemon would run it. Modern distcc (the version actually
packaged today) fixed this by refusing to run anything whose resolved
compiler isn't on an explicit whitelist (dcc_check_compiler_whitelist) -
confirmed experimentally against the real apt package while building
this lab: even a plain `cc -c x.c -o x.o` job is refused by default,
let alone an injected one.

To keep the *historical* CVE exploitable (teaching the real wire
protocol and the real Metasploit module, exploit/unix/misc/distcc_exec),
this reimplements just enough of that wire protocol - not the whitelist
check that superseded it - so the module's unmodified request succeeds
exactly as it would have against the original, vulnerable 3.x line
circa 2004.
"""
import socket
import subprocess
import threading

PORT = 3632


def read_exact(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("short read")
        buf += chunk
    return buf


def read_token(conn):
    header = read_exact(conn, 12)
    name = header[:4].decode()
    value = int(header[4:], 16)
    return name, value


def write_token(conn, name, value):
    conn.sendall(name.encode() + f"{value:08x}".encode())


def handle_client(conn, addr):
    try:
        name, _version = read_token(conn)
        if name != "DIST":
            return
        name, argc = read_token(conn)
        if name != "ARGC":
            return
        argv = []
        for _ in range(argc):
            name, length = read_token(conn)
            if name != "ARGV":
                return
            argv.append(read_exact(conn, length).decode(errors="replace"))
        name, dlen = read_token(conn)
        if name == "DOTI":
            read_exact(conn, dlen)  # preprocessed source - discard

        print(f"[distccd] job from {addr}, argv: {argv!r}")
        # Real distccd execs argv[0] with the argv array directly
        # (execvp-style) - it never re-joins and re-tokenizes argv
        # through a shell. That distinction is exactly what the real
        # exploit (and Metasploit's CmdStager for this module) relies
        # on: argv = ["sh", "-c", "<payload>", "#", ...trailing
        # compiler-looking args...]. sh's own -c takes argv[2] as its
        # command string verbatim, and the extra trailing args become
        # sh's own harmless positional parameters ($0, $1, ...) - not
        # something a join-then-reparse would reproduce correctly.
        subprocess.Popen(argv)

        # Minimal, always-success response so the client doesn't hang
        # waiting on a job it already triggered.
        write_token(conn, "DONE", 1)
        write_token(conn, "STAT", 0)
        write_token(conn, "SERR", 0)
        write_token(conn, "SOUT", 0)
        write_token(conn, "DOTO", 0)
    except (ConnectionError, ValueError, UnicodeDecodeError) as exc:
        print(f"[distccd] {addr} aborted: {exc!r}")
    finally:
        conn.close()


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", PORT))
    srv.listen(20)
    print(f"[distccd] listening on {PORT}")
    while True:
        conn, addr = srv.accept()
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()


if __name__ == "__main__":
    main()
