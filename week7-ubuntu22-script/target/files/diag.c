/*
 * diag.c - "system diagnostics helper"
 *
 * Installed SUID root. Meant to let any local user capture a quick
 * snapshot of running processes without needing sudo. The bug: it
 * resolves the "ps" command by name instead of an absolute path, so it
 * trusts the caller's PATH - and it never drops its root privileges
 * first. execvp() replaces this process image directly (no shell in
 * between), so whatever "ps" PATH resolves to inherits our euid 0
 * as-is.
 */
#include <stdio.h>
#include <unistd.h>

int main(void) {
    printf("[diag] collecting process snapshot...\n");
    fflush(stdout);
    char *const argv[] = {"ps", "aux", NULL};
    execvp("ps", argv);
    perror("[diag] execvp failed");
    return 1;
}
