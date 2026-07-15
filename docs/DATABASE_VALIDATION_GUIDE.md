# Database Validation Guide

## Running all checks

```bash
sqlcmd -S $DB_SERVER,$DB_PORT -d $DB_NAME -U $DB_USER -P $DB_PASSWORD -C \
       -v DB_NAME="$DB_NAME" -i scripts/verify_database.sql
```

This runs every script in `database/sqlserver/validation/` in order and
prints a `PASS`/`WARNING`/`FAIL`-style line per check. It's what
`install_database.sh`/`.ps1` run automatically at the end of installation,
and what the Docker `db-init` service uses to decide whether to exit 0
(success, `backend` may start) or fail loudly (blocks `backend`).

## What each check does and why it's severity-tiered the way it is

| Script | On failure | Why |
|---|---|---|
| `validate_tables.sql` | **Hard fail** (`RAISERROR`) | A missing table means the app cannot function at all. |
| `validate_database_version.sql` | **Hard fail** | No `SchemaVersion` row means install never completed. |
| `validate_constraints.sql` | Warning | Missing constraints are a data-integrity risk, not an immediate outage. |
| `validate_indexes.sql` | Warning | Missing indexes are a performance concern only. |
| `validate_users.sql` | Warning | The app's own `initDB()` self-heals this on next backend startup. |
| `validate_lookup_data.sql` / `validate_configuration.sql` | Informational | N/A for this project — see `DATABASE_STRUCTURE_REPORT.md` §2-3. |

## Running an individual check

```bash
sqlcmd -S $DB_SERVER,$DB_PORT -d $DB_NAME -U $DB_USER -P $DB_PASSWORD -C \
       -i database/sqlserver/validation/validate_tables.sql
```

## When to run validation

- Immediately after a first install.
- Immediately after any migration.
- Immediately after any restore.
- As part of the Docker Compose `db-init` service, every time the stack
  starts (cheap to run, catches drift early).
