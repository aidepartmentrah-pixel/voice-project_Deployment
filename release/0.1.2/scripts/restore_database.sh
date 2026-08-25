#!/usr/bin/env bash
# restore_database.sh — restores BloodBankDB from a .bak file.
#
# Manual run: ./restore_database.sh /path/on/host/to/backup.bak
# Platform-driven run: set RAH_BACKUP_SOURCE_PATH instead of a positional
# argument — the RAH Offline Installation Platform's own recovery.py
# resolves this to a real host path outside this deployment (Backup
# Isolation Rule), not assumed to already be under ./backups/. See
# docs/development/Bugs/Bug 3 — Backup Path Contract Not Honored.md in
# the Air-Gapped-System-Platform repo.
# WARNING: overwrites the current database. Stop the backend first.
set -euo pipefail

if [ -n "${RAH_BACKUP_SOURCE_PATH:-}" ]; then
  HOST_BACKUP_PATH="$RAH_BACKUP_SOURCE_PATH"
elif [ "$#" -eq 1 ]; then
  HOST_BACKUP_PATH="$1"
else
  echo "Usage: $0 <path-to-backup-on-host>" >&2
  echo "(or set RAH_BACKUP_SOURCE_PATH in the environment)" >&2
  exit 1
fi

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RELEASE_DIR/compose"
[ -f .env ] && { set -a; source .env; set +a; }

: "${DB_NAME:?DB_NAME is required (set in compose/.env)}"
: "${DB_SA_PASSWORD:?DB_SA_PASSWORD is required (set in compose/.env)}"

if [ ! -f "$HOST_BACKUP_PATH" ]; then
  echo "ERROR: $HOST_BACKUP_PATH not found on host." >&2
  exit 1
fi

BACKUP_FILENAME="$(basename "$HOST_BACKUP_PATH")"
CONTAINER_BACKUP_PATH="/var/opt/mssql/backup/${BACKUP_FILENAME}"

echo "==> This will REPLACE the current ${DB_NAME} database. Stopping backend first..."
docker compose stop backend

# Copy the artifact into the container explicitly rather than assuming it's
# already visible via the ./backups/ bind mount — true for a manual run
# using that directory, not guaranteed for a Platform-supplied path outside
# this deployment.
MSYS_NO_PATHCONV=1 docker compose cp "$HOST_BACKUP_PATH" "sqlserver:${CONTAINER_BACKUP_PATH}"

# MSYS_NO_PATHCONV=1 is a no-op on real Linux — only matters if this is ever
# run from Windows Git Bash, where MSYS otherwise mangles the --workdir
# argument into a Windows-style path and the exec fails outright.
MSYS_NO_PATHCONV=1 docker compose exec -T --workdir /opt/dbpkg/scripts sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$DB_SA_PASSWORD" -C \
  -v DB_NAME="$DB_NAME" -v BACKUP_PATH="$CONTAINER_BACKUP_PATH" \
  -i restore_database.sql

echo "==> Restore complete. Restarting backend..."
docker compose start backend
echo "==> Done. Run scripts/verify_installation.sh to confirm."
