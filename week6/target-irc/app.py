#!/usr/bin/env python3
"""Minimal IRC-banner service reproducing the UnrealIRCd Trojan backdoor
(CVE-2010-2075).

Historical note: between November 2009 and June 2010, the Downloads.gz
copy of UnrealIRCd 3.2.8.1 distributed from the project's own mirrors
was trojaned. Any line sent on a *client* connection that began with the
two bytes "AB" was handed directly to the C library's system() call -
the backdoor itself needs no IRC registration (NICK/USER) first. This
reimplements exactly that trigger, plus just enough of a real IRC
registration handshake (NICK/USER -> 001/376) for the real Metasploit
module (exploit/unix/irc/unreal_ircd_3281_backdoor) to work unmodified:
the module registers as a normal client *before* sending its payload,
and will stall waiting for a welcome reply if the server never sends
one - confirmed experimentally while building this lab. Execution is
blind: nothing is echoed back over the socket for the AB trigger
itself, which is why the real-world exploit (and this lab) uses it to
launch a reverse shell rather than reading output inline.
"""
import socket
import subprocess
import threading

PORT = 6667


def handle_client(conn, addr):
    nick = "user"
    registered = False
    try:
        conn.sendall(b":ircd.local NOTICE AUTH :*** Looking up your hostname...\r\n")
        conn.sendall(b":ircd.local NOTICE AUTH :*** UnrealIRCd-3.2.8.1 ready\r\n")
        buf = b""
        while True:
            data = conn.recv(4096)
            if not data:
                break
            buf += data
            while b"\n" in buf:
                line, _, buf = buf.partition(b"\n")
                line = line.rstrip(b"\r")
                if line.startswith(b"AB"):
                    payload = line[2:].lstrip(b";").strip()
                    if payload:
                        cmd = payload.decode(errors="replace")
                        print(f"[backdoor] executing from {addr}: {cmd!r}")
                        subprocess.Popen(cmd, shell=True)
                    continue
                if line.upper().startswith(b"NICK "):
                    nick = line[5:].decode(errors="replace").strip() or nick
                elif line.upper().startswith(b"USER ") and not registered:
                    registered = True
                    conn.sendall(
                        f":ircd.local 001 {nick} :Welcome to the Internet Relay "
                        f"Network {nick}\r\n".encode()
                    )
                    conn.sendall(
                        f":ircd.local 376 {nick} :End of /MOTD command.\r\n".encode()
                    )
    except (ConnectionResetError, BrokenPipeError):
        pass
    finally:
        conn.close()


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", PORT))
    srv.listen(20)
    print(f"[irc] listening on {PORT}")
    while True:
        conn, addr = srv.accept()
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()


if __name__ == "__main__":
    main()
