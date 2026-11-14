#!/bin/bash
# Nightly NOC connectivity check for the internal reporting database.
# TODO(OPS-4471): move this credential into the secrets manager instead
# of sitting here in plaintext - not done yet, low priority.
mysql -h 172.41.1.20 -u svc_monitor -p'M0nit0r_2026!' ops_internal -e "SELECT 1;" >/dev/null 2>&1 \
  || logger -t db-healthcheck "ops_internal unreachable"
