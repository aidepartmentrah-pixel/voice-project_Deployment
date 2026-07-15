# Database Backup Guide

## When to back up

- Before every migration applied to a database with real data.
- Before every application/Docker image update in production (per the RAH
  Lab Operator Manual's rollback policy).
- On a regular schedule once this is running in the Offline Environment
  (recommend daily; decide the retention window with hospital IT).

## Running a backup

```bash
sqlcmd -S $DB_SERVER,$DB_PORT -U sa -P $DB_SA_PASSWORD -C \
       -v DB_NAME="$DB_NAME" \
       -v BACKUP_PATH="/var/opt/mssql/backup/${DB_NAME}_$(date +%Y%m%d_%H%M%S).bak" \
       -i scripts/backup_database.sql
```

In the Dockerized deployment, `/var/opt/mssql/backup/` should be a mounted
volume/bind-mount **outside** the `sqlserver` container's writable layer, so
backups survive container recreation and are easy to copy off the offline
server for safekeeping (per the "store backups outside the container" rule).

## What gets backed up

A full `BACKUP DATABASE` of `BloodBankDB` — every table (`HospitalUsers`,
`TransfusionRequests`, `BloodDeliveries`, `ExternalDeliveries`,
`VoiceTranscriptions`, `SchemaVersion`), indexes, and constraints. Excel
files under `node-backend/uploads/excel/` and raw audio under
`node-backend/uploads/` are **not** part of this database backup — they're
file-based and live in their own Docker volume (see Phase 2 documentation);
back those up separately if needed.

## Verifying a backup is usable

```sql
RESTORE VERIFYONLY FROM DISK = N'/var/opt/mssql/backup/BloodBankDB.bak';
```

Run this after every backup, not just before a restore — a backup you've
never test-verified is not a backup you can rely on.
