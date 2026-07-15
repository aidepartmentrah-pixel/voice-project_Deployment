# Backup & Restore — Offline

## Backing up

```bash
cd release
./scripts/backup_database.sh
```

Writes a timestamped `.bak` file to `release/backups/` on the host (mounted
into the `sqlserver` container at `/var/opt/mssql/backup` — see
`compose/docker-compose.yml`), so it survives container recreation and can
be copied off the server for safekeeping.

Recommended: run this on a daily schedule (e.g. host cron calling this
script) and copy the resulting `.bak` files to separate storage per
hospital IT policy.

## Restoring

```bash
cd release
./scripts/restore_database.sh /path/to/backups/BloodBankDB_20260101_020000.bak
```

**This overwrites the current database.** Stop `backend` first so it isn't
holding connections open:

```bash
docker compose stop backend
./scripts/restore_database.sh <path-to-backup>
docker compose start backend
```

## Full detail

See `docs/DATABASE_BACKUP_GUIDE.md` and `docs/DATABASE_RESTORE_GUIDE.md` in
the repo root for the underlying SQL and edge cases (e.g. restoring a
backup taken on a different SQL Server instance).
