-- internal-only database, only reachable from pivot's internal IP (see
-- entrypoint-wrapper.sh). Populated automatically by the mariadb
-- entrypoint into the `ops_internal` database (created via
-- MYSQL_DATABASE); svc_monitor (created via MYSQL_USER/MYSQL_PASSWORD)
-- is granted full access to that one database only.

CREATE TABLE IF NOT EXISTS device_inventory (
    id INT PRIMARY KEY AUTO_INCREMENT,
    hostname VARCHAR(64),
    asset_tag VARCHAR(32),
    role VARCHAR(64)
);

INSERT INTO device_inventory (hostname, asset_tag, role) VALUES
    ('pivot', 'AST-10492', 'edge web server (dual-homed)'),
    ('db', 'AST-10493', 'internal reporting database'),
    ('noc-relay-01', 'AST-10511', 'decommissioned - do not use');

CREATE TABLE IF NOT EXISTS maintenance_journal (
    id INT PRIMARY KEY AUTO_INCREMENT,
    entry_date DATE,
    author VARCHAR(64),
    notes TEXT
);

INSERT INTO maintenance_journal (entry_date, author, notes) VALUES
    ('2026-09-02', 'ops-team', 'Rotated TLS cert on noc-relay-01 before decommission.'),
    ('2026-10-14', 'ops-team', 'svc_monitor healthcheck still hardcoded in cron on pivot - ticket OPS-4471 open.'),
    ('2026-11-01', 'deploy-bot', 'Final handoff note from the pivot deployment window. FLAG{w11_2_chisel_reverse_socks_pivot_complete}');
