-- internal-only database, only reachable from webapp's internal IP (see
-- entrypoint-wrapper.sh). Populated automatically by the mariadb
-- entrypoint into the `internal` database (created via MYSQL_DATABASE).

CREATE TABLE IF NOT EXISTS flags (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(64),
    value VARCHAR(128)
);

INSERT INTO flags (name, value)
VALUES ('flag5', 'flag{w5_5_pivot_internal_db_final}');

CREATE TABLE IF NOT EXISTS report_archive (
    id INT PRIMARY KEY AUTO_INCREMENT,
    subject VARCHAR(128),
    body TEXT
);

INSERT INTO report_archive (subject, body) VALUES
    ('Q1 planning', 'Reminder: internal-api and internal-db should only ever be reachable from webapp. Verify after every infra change.'),
    ('Credential rotation', 'svc_pivot password has not been rotated since this environment was built. File a ticket.');
