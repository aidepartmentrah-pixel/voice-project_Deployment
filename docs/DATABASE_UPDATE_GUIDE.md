# Database Update Guide

Existing production databases are **never recreated**. All schema evolution
after the initial install goes through `database/sqlserver/migrations/`.

## Adding a new migration

See `database/sqlserver/migrations/README.md` for the full process. Summary:

1. Add `database/sqlserver/migrations/NNN_description.sql`, guarded with
   `IF NOT EXISTS` checks (same idempotent style as `install/`).
2. End it with an `INSERT INTO SchemaVersion (version, description) VALUES (...)`.
3. Add a corresponding entry to `database/sqlserver/rollback/README.md`
   describing the manual rollback (usually: restore from backup — see
   `DATABASE_BACKUP_GUIDE.md`).
4. **Always take a backup immediately before applying a migration to a
   database with real data** (`scripts/backup_database.sql`).

## Running a migration

```bash
sqlcmd -S $DB_SERVER,$DB_PORT -d $DB_NAME -U $DB_USER -P $DB_PASSWORD -C \
       -i database/sqlserver/migrations/NNN_description.sql
```

Then re-run `scripts/verify_database.sql` to confirm the database is in the
expected state, and check `SELECT MAX(version) FROM SchemaVersion` matches
what you just applied.

## What NOT to do

- Do not edit files under `install/` once a database package version has
  shipped — those represent "what a fresh install looks like on day one,"
  not "what the database looks like today." New columns/tables/indexes are
  migrations, not edits to `install/002_create_schema.sql`.
- Do not add new logic to `server.js`'s `initDB()` bootstrap going forward —
  it's left in place for backward compatibility, but new schema changes
  belong in `migrations/` (see that folder's README for why).
