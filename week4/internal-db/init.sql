-- internal-only database, only reachable from the webapp host on the
-- internal network. Populated automatically by the mariadb entrypoint
-- into the `internal` database (created via MYSQL_DATABASE env var).

CREATE TABLE IF NOT EXISTS flags (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(64),
    value VARCHAR(128)
);

INSERT INTO flags (name, value)
VALUES ('flag5', 'flag{w4_5_p1v0t_1nt3rn4l_db_f00th0ld_3xp4nd}');

CREATE TABLE IF NOT EXISTS reports (
    id INT PRIMARY KEY AUTO_INCREMENT,
    subject VARCHAR(128),
    body TEXT
);

INSERT INTO reports (subject, body) VALUES
    ('Q4 audit', 'Reminder: rotate the svc_reports credentials after go-live. Never happened.'),
    ('Network segmentation', 'internal-db should only ever be reachable from webapp. Do not expose it further.');
