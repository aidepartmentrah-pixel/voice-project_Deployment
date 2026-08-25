/*
  restore_database.sql
  Restores BloodBankDB from a .bak file produced by backup_database.sql.
  WITH REPLACE — this overwrites whatever database currently exists at
  DB_NAME. Confirm you actually want to replace the current database before
  running this (see docs/DATABASE_RESTORE_GUIDE.md).

    sqlcmd -S $(DB_SERVER),$(DB_PORT) -U sa -P $(DB_SA_PASSWORD) -C \
           -v DB_NAME="$(DB_NAME)" -v BACKUP_PATH="/var/opt/mssql/backup/BloodBankDB.bak" \
           -i scripts/restore_database.sql

  Runs as "sa" (DB_SA_PASSWORD), not the application's DB_USER — RESTORE
  DATABASE requires sysadmin/dbcreator-level rights regardless of db_owner
  status on the target database.

  If the logical file names in the .bak differ from a fresh install (e.g.
  restoring a backup taken on HCAT into a new container), first run:
    RESTORE FILELISTONLY FROM DISK = N'$(BACKUP_PATH)';
  and adjust the MOVE clauses below to match.
*/

-- DB_NAME and BACKUP_PATH must be supplied by the caller via -v (see the
-- usage block above) — no :setvar default here, same reasoning as
-- backup_database.sql (see Bug 5 in the Air-Gapped-System-Platform repo).

ALTER DATABASE [$(DB_NAME)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

RESTORE DATABASE [$(DB_NAME)]
FROM DISK = N'$(BACKUP_PATH)'
WITH REPLACE, RECOVERY, STATS = 10;
GO

ALTER DATABASE [$(DB_NAME)] SET MULTI_USER;
GO
