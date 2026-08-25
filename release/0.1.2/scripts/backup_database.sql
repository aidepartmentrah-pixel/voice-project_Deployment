/*
  backup_database.sql
  Full backup of BloodBankDB to a .bak file. Run via sqlcmd with scripting
  variables so server/database/path stay configurable:

    sqlcmd -S $(DB_SERVER),$(DB_PORT) -U sa -P $(DB_SA_PASSWORD) -C \
           -v DB_NAME="$(DB_NAME)" -v BACKUP_PATH="/var/opt/mssql/backup/BloodBankDB_$(date +%Y%m%d_%H%M%S).bak" \
           -i scripts/backup_database.sql

  Runs as "sa" (DB_SA_PASSWORD), not the application's DB_USER — BACKUP
  DATABASE needs db_backupoperator or higher, and keeping this on the same
  ops-only credential as the installer avoids granting the app's own login
  more than it needs at runtime.

  In the Dockerized deployment, mount a host/volume path for BACKUP_PATH so
  the .bak file lands outside the SQL Server container.
*/

-- DB_NAME and BACKUP_PATH must be supplied by the caller via -v (see the
-- usage block above) — no :setvar default here. sqlcmd's :setvar applies
-- unconditionally, after and over a caller-supplied -v, so a hardcoded
-- default here would silently discard whatever the real caller passed
-- (see docs/development/Bugs/Bug 5 — Hardcoded Setvar Override.md in the
-- Air-Gapped-System-Platform repo).

-- No COMPRESSION -- this deployment runs SQL Server Express
-- (docker-compose.yml's own MSSQL_PID: Express), which does not support
-- backup compression at all: "BACKUP DATABASE WITH COMPRESSION is not
-- supported on Express Edition." Confirmed live, 2026-08-25 (Pass 4,
-- controlled-failure qualification) -- WITH COMPRESSION made this exact
-- BACKUP DATABASE statement fail outright, every time, on this app's own
-- real edition choice.
BACKUP DATABASE [$(DB_NAME)]
TO DISK = N'$(BACKUP_PATH)'
WITH FORMAT, INIT, NAME = N'$(DB_NAME)-Full', SKIP, NOREWIND, NOUNLOAD, STATS = 10;
GO
