-- internal-only database, only reachable from build-ci's internal IP
-- (see entrypoint-wrapper.sh). Populated into the `ops_ci` database
-- (created via MYSQL_DATABASE); svc_ci (created via MYSQL_USER/
-- MYSQL_PASSWORD) has full access to this one database only.

CREATE TABLE IF NOT EXISTS build_queue (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project VARCHAR(64),
    status VARCHAR(32),
    queued_at DATETIME
);

INSERT INTO build_queue (project, status, queued_at) VALUES
    ('stage-7741', 'complete', '2026-11-10 03:14:00'),
    ('legacy-migration', 'blocked', '2026-11-12 09:02:00'),
    ('decommission-cleanup', 'complete', '2026-11-15 22:40:00');

CREATE TABLE IF NOT EXISTS credentials (
    id INT PRIMARY KEY AUTO_INCREMENT,
    service VARCHAR(64),
    username VARCHAR(64),
    password_hash VARCHAR(128),
    notes TEXT
);

INSERT INTO credentials (service, username, password_hash, notes) VALUES
    ('old-jenkins', 'jenkins', '$1$decom01$7U4nQe0Z1h1rGQhVY6m0y0', 'Decommissioned 2025 - box no longer exists, do not bother.'),
    ('legacy-svc', 'root', '$1$w12salt$HEgn6Sti/YY8k3Fgo/iA60', 'legacy-svc still shares this root password across every account on the box - ops ticket OPS-4488 open to fix. FLAG{w12_7_internal_db_pivot_credential_crack}'),
    ('noc-relay-01', 'admin', '$1$decom02$3pQ8l2xWn9f0b7Jc5tR1z1', 'Decommissioned alongside old-jenkins, same cleanup window.');
