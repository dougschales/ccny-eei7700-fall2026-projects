/*
 * statusd - "internal fleet status collector"
 *
 * Reads a one-line status message from a client and files it away.
 * Intentionally vulnerable (Week 10: Binaries & Buffer Overflows):
 *
 *   log_status() copies the caller-supplied message into a fixed-size
 *   stack buffer with read(), with no bound tied to the buffer's real
 *   size. A message longer than STATUS_BUF_LEN overwrites whatever
 *   follows buf[] on the stack - saved registers and, eventually, the
 *   return address.
 *
 * This binary is launched per-connection by xinetd with stdin/stdout
 * already wired to the client socket (see files/statusd.xinetd), so it
 * never touches sockets itself - that is also why a plain shell spawned
 * by injected shellcode is immediately interactive over the connection.
 *
 * Release artifacts (this binary, this source file, and the matching
 * release notes) are mirrored as a set under internal/releases/ - if
 * you pulled this file via the docs portal, the release notes sit
 * right alongside it. So does a stray on-call engineer's repro notes
 * from a prior ticket on this exact service - worth a look if you ever
 * need to run this binary the same way xinetd does.
 */
#include <unistd.h>

#define STATUS_BUF_LEN 64

void log_status(void) {
    char buf[STATUS_BUF_LEN];
    /* VULNERABLE: up to 512 bytes read into a 64-byte buffer. */
    read(STDIN_FILENO, buf, 512);
}

int main(void) {
    static const char banner[] = "statusd 1.4 - send a status line\n";
    write(STDOUT_FILENO, banner, sizeof(banner) - 1);
    log_status();
    return 0;
}
