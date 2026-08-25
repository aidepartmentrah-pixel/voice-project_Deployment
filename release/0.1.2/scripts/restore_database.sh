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
DEPLOY_DIR="${RAH_ACTIVE_DEPLOYMENT_PATH:-$RELEASE_DIR}"
cd "$RELEASE_DIR/compose"
[ -f "$DEPLOY_DIR/compose/.env" ] && { set -a; source "$DEPLOY_DIR/compose/.env"; set +a; }
COMPOSE=(docker compose --env-file "$DEPLOY_DIR/compose/.env")
export BACKUPS_HOST_PATH="$DEPLOY_DIR/backups"
export DEPLOY_DATABASE_PATH="$DEPLOY_DIR/database"
export DEPLOY_SCRIPTS_PATH="$DEPLOY_DIR/scripts"
export DEPLOY_NGINX_CONF_PATH="$DEPLOY_DIR/compose/nginx/nginx.conf"
export DEPLOY_NGINX_CERTS_PATH="$DEPLOY_DIR/compose/nginx/certs"

: "${DB_NAME:?DB_NAME is required (set in compose/.env)}"
: "${DB_SA_PASSWORD:?DB_SA_PASSWORD is required (set in compose/.env)}"

if [ ! -f "$HOST_BACKUP_PATH" ]; then
  echo "ERROR: $HOST_BACKUP_PATH not found on host." >&2
  exit 1
fi

BACKUP_FILENAME="$(basename "$HOST_BACKUP_PATH")"
CONTAINER_BACKUP_PATH="/var/opt/mssql/backup/${BACKUP_FILENAME}"

echo "==> This will REPLACE the current ${DB_NAME} database. Stopping backend first..."
"${COMPOSE[@]}" stop backend

# Copy the artifact into the container explicitly rather than assuming it's
# already visible via the ./backups/ bind mount — true for a manual run
# using that directory, not guaranteed for a Platform-supplied path outside
# this deployment.
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" cp "$HOST_BACKUP_PATH" "sqlserver:${CONTAINER_BACKUP_PATH}"

# MSYS_NO_PATHCONV=1 is a no-op on real Linux — only matters if this is ever
# run from Windows Git Bash, where MSYS otherwise mangles the --workdir
# argument into a Windows-style path and the exec fails outright.
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec -T --workdir /opt/dbpkg/scripts sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$DB_SA_PASSWORD" -C \
  -v DB_NAME="$DB_NAME" -v BACKUP_PATH="$CONTAINER_BACKUP_PATH" \
  -i restore_database.sql

echo "==> Restore complete. Restarting backend..."
"${COMPOSE[@]}" start backend
echo "==> Done. Run scripts/verify_installation.sh to confirm."
