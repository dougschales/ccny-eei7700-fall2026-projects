# Internal database credentials for the reporting archive. internal-db is
# only reachable from webapp's own network position - not referenced
# anywhere in app.py, kept here for the ops runbook script (removed from
# this build; nobody deleted the file itself).
INTERNAL_DB_HOST = "internal-db"
INTERNAL_DB_PORT = 3306
INTERNAL_DB_NAME = "internal"
INTERNAL_DB_USER = "svc_pivot"
INTERNAL_DB_PASSWORD = "P1v0t_M3_2026!"
