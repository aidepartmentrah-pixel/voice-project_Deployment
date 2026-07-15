# Migrations

## How this differs from `server.js`'s inline bootstrap

`node-backend/server.js`'s `initDB()` currently contains a handful of inline
`IF NOT EXISTS (...) ALTER TABLE ... ADD ...` blocks (the `nurse_unit_*`
columns, `saved_by` columns, the `HospitalUsers`/`ExternalDeliveries` table
creation, `ExternalDeliveries.components_json`). Those are left **as-is** in
the application code — they're idempotent and harmless to keep running on
every backend startup, and removing them isn't necessary to satisfy "preserve
existing behavior."

Going forward, however, **new schema changes should not be added to
`initDB()`**. Instead, add a new numbered file to this folder. This keeps
schema evolution versioned, reviewable, and independent of application
deploys — matching the RAH Lab Operator Manual's rule that "existing
production databases should never be recreated... structural modifications
must be applied through controlled migration procedures."

## Adding a migration

1. Create `NNN_short_description.sql` (zero-padded, incrementing — start at
   `001_` since the initial install package already covers everything up to
   and including today's schema).
2. Guard every statement with an existence check (`IF NOT EXISTS (...)`),
   the same pattern used throughout `database/sqlserver/install/`, so the
   migration is safe to run more than once.
3. End the file with an insert into `SchemaVersion`:
   ```sql
   INSERT INTO SchemaVersion (version, description)
   VALUES ('1.1.0', 'Describe what changed and why');
   ```
4. Add a matching rollback file in `database/sqlserver/rollback/` (see that
   folder's README for what "rollback" means for each kind of change).
5. Add or update a check in `database/sqlserver/validation/` if the
   migration should be asserted as present going forward.

## Running migrations

`scripts/install_database.sh` / `.ps1` run everything in `install/` only on
a database that doesn't yet have a `SchemaVersion` row (first install). For
an existing database, run each new file in this folder in order, e.g.:

```bash
sqlcmd -S $DB_SERVER,$DB_PORT -d $DB_NAME -U $DB_USER -P $DB_PASSWORD -i database/sqlserver/migrations/001_example.sql
```

No migrations exist yet beyond the initial install package — this folder is
currently empty except for this README.
