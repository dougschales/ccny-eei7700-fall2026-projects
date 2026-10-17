#!/bin/bash
# Nightly workspace cleanup - deployed in a hurry, permissions never
# got locked down after the deploy script ran `chmod 777` on the whole
# directory "just to get it working". Runs as root every minute via
# /etc/cron.d/maintenance.
find /home/trainee/scratch -type f -name '*.tmp' -mtime +1 -delete 2>/dev/null

