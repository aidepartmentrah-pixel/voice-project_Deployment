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

-- Deliberately no :setvar defaults here: sqlcmd's own :setvar
-- unconditionally overwrites a value already passed via -v, so a
-- hardcoded default would silently discard the real, Packager-computed
-- DB_NAME/BACKUP_PATH the calling script (release/*/scripts/backup_database.sh)
-- always passes -- see database/sqlserver/install/001_create_database.sql's
-- own comment for the full reasoning (same real, latent bug shape).

BACKUP DATABASE [$(DB_NAME)]
TO DISK = N'$(BACKUP_PATH)'
WITH FORMAT, INIT, NAME = N'$(DB_NAME)-Full', SKIP, NOREWIND, NOUNLOAD, COMPRESSION, STATS = 10;
GO
