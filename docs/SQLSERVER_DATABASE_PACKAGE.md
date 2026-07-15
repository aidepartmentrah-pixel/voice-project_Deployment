# SQL Server Database Package — voice-project (BloodBankDB)

This package makes BloodBankDB's schema portable and repeatable. It was
built by reading `node-backend/db.js` and every raw SQL query in
`node-backend/server.js` — see `DATABASE_STRUCTURE_REPORT.md` for what's
confirmed from code vs. inferred from query usage.

## Layout

```
database/sqlserver/
├── install/          First-time install, run in numeric order (001-011)
├── migrations/        Future schema changes go here, not into install/
├── validation/         Post-install correctness checks
└── rollback/            Undo for a failed first install only

scripts/
├── install_database.sh    Linux — used by the Docker db-init service
├── install_database.ps1   Windows — for local validation on this laptop
├── backup_database.sql
├── restore_database.sql
└── verify_database.sql    Runs every validation/ check in sequence

docs/
├── SQLSERVER_DATABASE_PACKAGE.md   (this file)
├── DATABASE_INSTALL_GUIDE.md
├── DATABASE_UPDATE_GUIDE.md
├── DATABASE_BACKUP_GUIDE.md
├── DATABASE_RESTORE_GUIDE.md
├── DATABASE_VALIDATION_GUIDE.md
└── DATABASE_STRUCTURE_REPORT.md
```

## Design decisions worth knowing

- **Idempotent by default.** Every install/migration script uses
  `IF NOT EXISTS` guards — the same pattern `server.js`'s own `initDB()`
  bootstrap already uses. Re-running the install package against an
  already-installed database is a safe no-op.
- **Admin user seeding stays in the app, not SQL.** `server.js`'s `initDB()`
  already bcrypt-hashes and seeds a default admin correctly; this package
  doesn't reimplement password hashing in T-SQL. See
  `install/010_seed_users_roles.sql`.
- **No lookup/configuration tables invented.** This app doesn't use them —
  see `DATABASE_STRUCTURE_REPORT.md` §2-3.
- **Fully environment-driven.** `node-backend/db.js` no longer has hardcoded
  fallback server/database/user values — it throws a clear error if
  `DB_SERVER`/`DB_NAME`/`DB_USER`/`DB_PASSWORD` are missing, instead of
  silently connecting to a stale default.
- **Schema versioning is new.** Nothing previously recorded a schema
  version; `SchemaVersion` (created in `install/011_...sql`) is the anchor
  future migrations append to.

## Consumed by Phase 2 (Dockerization)

`scripts/install_database.sh` is designed to run unattended inside the
Docker Compose `db-init` service — it waits for the `sqlserver` container's
healthcheck, then installs and verifies. See the repo root
`docker-compose.yml` and `docs/` under `release/documentation/` for the full
Dockerized deployment.
