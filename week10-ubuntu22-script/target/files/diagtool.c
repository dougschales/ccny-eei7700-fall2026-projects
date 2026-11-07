/*
 * diagtool - root's "fleet diagnostics" helper, run periodically by cron.
 *
 * Intentionally vulnerable the same way statusd is: log_tag() copies a
 * caller-supplied message into a fixed-size stack buffer with read(),
 * with no bound tied to the buffer's real size. This binary is plain
 * (non-SUID) - root's own cron job runs it directly, so shellcode landed
 * through this overflow runs as root without any SUID bit involved.
 * This is the Week 10 privilege-escalation vector, reusing the exact
 * technique from the remote statusd exploit against a second, local
 * target instead.
 */
#include <unistd.h>

#define TAG_BUF_LEN 200

void log_tag(void) {
    char buf[TAG_BUF_LEN];
    /* VULNERABLE: up to 512 bytes read into a 200-byte buffer. */
    read(STDIN_FILENO, buf, 512);
}

int main(void) {
    static const char banner[] = "diagtool - send a diagnostic tag\n";
    write(STDOUT_FILENO, banner, sizeof(banner) - 1);
    log_tag();
    return 0;
}
