# Database Restore Guide

## Before you restore

`scripts/restore_database.sql` uses `WITH REPLACE` — it **overwrites**
whatever database currently exists at `$DB_NAME`. Confirm you actually mean
to discard the current database's contents before running this. If in
doubt, take a fresh backup of the current state first (see
`DATABASE_BACKUP_GUIDE.md`) so you can restore back to it if the restore was
a mistake.

## Running a restore

```bash
sqlcmd -S $DB_SERVER,$DB_PORT -U sa -P $DB_SA_PASSWORD -C \
       -v DB_NAME="$DB_NAME" \
       -v BACKUP_PATH="/var/opt/mssql/backup/BloodBankDB.bak" \
       -i scripts/restore_database.sql
```

This puts the database into `SINGLE_USER` mode, restores, then returns it to
`MULTI_USER`. Any active connections (e.g. a running `node-backend`
container) will be dropped during this — stop the `backend` service first
in a Docker Compose deployment.

## If the logical file names don't match

Restoring a `.bak` taken on a different SQL Server instance (e.g. HCAT) into
a fresh container can fail if the container's default data/log paths don't
match the backup's logical file names. First inspect:

```sql
RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backup/BloodBankDB.bak';
```

Then add `MOVE 'logical_name' TO 'new/path'` clauses to
`scripts/restore_database.sql`'s `RESTORE DATABASE` statement for each row
returned, before running it.

## After restoring

Run `scripts/verify_database.sql` to confirm the restored database matches
the expected structure, and check `SELECT MAX(version) FROM SchemaVersion`
to see which migrations it already includes — any migrations *not* yet
reflected there still need to be re-applied.
