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

:setvar DB_NAME "BloodBankDB"
:setvar BACKUP_PATH "/var/opt/mssql/backup/BloodBankDB.bak"

BACKUP DATABASE [$(DB_NAME)]
TO DISK = N'$(BACKUP_PATH)'
WITH FORMAT, INIT, NAME = N'$(DB_NAME)-Full', SKIP, NOREWIND, NOUNLOAD, COMPRESSION, STATS = 10;
GO
