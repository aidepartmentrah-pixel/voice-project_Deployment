# Rollback

## Initial installation rollback

`rollback_initial_install.sql` in this folder drops everything created by
`database/sqlserver/install/`. It is **only safe to run against a database
that has never held real production data** (e.g. a failed first install on
a fresh dev/offline environment). It is guarded to refuse to run if any of
the business tables contain rows, specifically to prevent it from being
misused against a live database with real patient/business records.

## Migration rollback

Per the RAH Lab Operator Manual (§3.9, §7.5): once a migration has touched
production data, "rollback" almost always means **restore the pre-migration
database backup**, not run an automated inverse script — an automated
`ALTER TABLE ... DROP COLUMN` on a live table is a real, immediate data-loss
risk if the migration turned out to already be in use. This package does not
generate automatic inverse-migration scripts.

For every migration added to `database/sqlserver/migrations/`, document the
manual rollback steps directly in that migration's own comments, and always
take a backup (see `scripts/backup_database.sql`) immediately before applying
it in production.
