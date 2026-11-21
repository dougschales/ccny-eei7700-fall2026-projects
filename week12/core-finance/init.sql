-- core-finance: innermost segment, only reachable from legacy-svc's
-- core-net address (see entrypoint-wrapper.sh). Database `finance_core`;
-- svc_ledger has full access to this one database only.

CREATE TABLE IF NOT EXISTS vendor_accounts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    vendor VARCHAR(64),
    account_ref VARCHAR(32),
    status VARCHAR(32)
);

INSERT INTO vendor_accounts (vendor, account_ref, status) VALUES
    ('NorthBridge Supply', 'VA-88213', 'active'),
    ('Paper & Toner Co', 'VA-88214', 'active'),
    ('Legacy Freight Partners', 'VA-88040', 'closed');

CREATE TABLE IF NOT EXISTS ledger_entries (
    id INT PRIMARY KEY AUTO_INCREMENT,
    entry_date DATE,
    author VARCHAR(64),
    memo TEXT
);

INSERT INTO ledger_entries (entry_date, author, memo) VALUES
    ('2026-09-18', 'finance-bot', 'Q3 reconciliation completed, no discrepancies.'),
    ('2026-10-30', 'ops-team', 'Migrated nightly sync off noc-relay-01 onto legacy-svc per OPS-4488.'),
    ('2026-11-17', 'deploy-bot', 'Final handoff note from the capstone deployment window. FLAG{w12_10_double_pivot_core_finance_complete}');
