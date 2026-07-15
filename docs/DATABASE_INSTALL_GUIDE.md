# Database Install Guide

## First installation (standalone, e.g. a fresh dev SQL Server)

Set the required environment variables, then run the installer for your OS.

### Linux / the Docker db-init service

```bash
export DB_SERVER=localhost
export DB_PORT=1433
export DB_NAME=BloodBankDB
export DB_USER=bloodbank_user
export DB_PASSWORD='<app password>'
export DB_SA_PASSWORD='<sa password>'   # only used to bootstrap the DB_USER login — never read by the app

./scripts/install_database.sh
```

`DB_SA_PASSWORD` authenticates as `sa` for the whole install — a fresh SQL
Server has no `bloodbank_user` login yet, so nothing else could create it.
`node-backend` itself never sees or uses `DB_SA_PASSWORD`; only
`DB_USER`/`DB_PASSWORD` (see `docker-compose.yml`).

### Windows (this Build Workstation), PowerShell

```powershell
$env:DB_SERVER = "localhost"
$env:DB_PORT   = "1433"
$env:DB_NAME   = "BloodBankDB"
$env:DB_USER   = "bloodbank_user"
$env:DB_PASSWORD = "<app password>"
$env:DB_SA_PASSWORD = "<sa password>"

.\scripts\install_database.ps1
```

Both scripts:
1. Wait for SQL Server to accept connections (up to ~60s).
2. Run `database/sqlserver/install/001_create_database.sql` — creates the
   database only if it doesn't already exist.
3. Run `002` through `011` in order against that database — schema, indexes,
   constraints, (no-op placeholders for views/procs/triggers/lookup/config
   — see `DATABASE_STRUCTURE_REPORT.md`), and the schema version record.
4. Run `scripts/verify_database.sql` and print PASS/WARNING/FAIL per check.

Expected final output line: `==> Database installation complete.`

## After install: start the backend once

The default admin account is seeded by `node-backend`'s own startup logic
(`initDB()` in `server.js`), not by this SQL package — start the backend
once against the newly installed database and it will create
`admin` / `admin123` automatically if `HospitalUsers` is empty. Change that
password immediately after first login.

## Docker Compose (Phase 2)

In the Dockerized stack, `install_database.sh` runs automatically inside the
`db-init` service, which waits on the `sqlserver` container's healthcheck
and exits 0 on success (or fails loudly, blocking `backend` from starting).
No manual steps needed there beyond setting `.env` correctly — see
`release/documentation/INSTALL_OFFLINE.md`.
