# Update Offline — voice-project (Blood Bank)

Updating replaces the `backend`/`whisper` Docker images while **preserving**
the existing database and uploaded files. The database itself is never
recreated — only migrated (see `DATABASE_UPDATE_GUIDE.md`).

## Before you start

1. Back up the database:
   ```bash
   ./scripts/backup_database.sh
   ```
2. Note the currently running image versions, in case you need to roll
   back (`docker compose images`).

## Step 1 — Load the new images

```bash
cd release
./scripts/load_images.sh
```

## Step 2 — Apply any new database migrations

If this release includes new files under `database/database/sqlserver/migrations/`
beyond what's already recorded in `SchemaVersion`, apply them **before**
starting the new backend image:

```bash
sqlcmd -S sqlserver,1433 -d "$DB_NAME" -U sa -P "$DB_SA_PASSWORD" -C \
       -i database/database/sqlserver/migrations/<new_file>.sql
```

(No migrations exist yet as of this release — this step is a no-op until a
future release adds one. Check `release/RELEASE_NOTES.md` for this
specific release's contents.)

## Step 3 — Restart the stack

```bash
./scripts/update_offline.sh
```

This runs `docker compose up -d` again — Compose recreates only the
containers whose image changed, leaving `sqlserver` (and its data volume)
untouched. If the optional RAG chatbot (`ollama`/`rag-chatbot`) was
already enabled at this site, `update_offline.sh` detects that
automatically and updates those two containers as well — no extra flag
needed. If it was **not** already enabled and you want to enable it as
part of this update, do that separately afterward (see
`INSTALL_OFFLINE.md`'s "Enabling the optional RAG chatbot") — updating
does not turn on a profile that wasn't already running.

## Step 4 — Verify

```bash
./scripts/verify_installation.sh
```

## If the update fails

Stop, then follow the rollback procedure in `TROUBLESHOOTING.md`: restore
the previous images (kept in `docker-images/` from the prior release) and,
if a migration was applied, restore the pre-update database backup from
Step 1's before-you-start backup.
