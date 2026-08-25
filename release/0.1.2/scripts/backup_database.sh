#!/usr/bin/env bash
# backup_database.sh — full BloodBankDB backup.
#
# Manual run (no RAH_BACKUP_OUTPUT_PATH set): backs up to ./backups/ on
# the host (bind-mounted into the sqlserver container), same as before.
#
# Platform-driven run (RAH_BACKUP_OUTPUT_PATH set): the RAH Offline
# Installation Platform expects a real file at that exact host path,
# outside this deployment (Backup Isolation Rule) — the ./backups/ bind
# mount's real host location isn't guaranteed to be that path, so the
# backup is taken inside the container at its own internal path, then
# copied out via `docker compose cp` to wherever Platform actually asked
# for it. See docs/development/Bugs/Bug 3 — Backup Path Contract Not
# Honored.md in the Air-Gapped-System-Platform repo.
set -euo pipefail

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

# Fix the bind-mounted backup directory's ownership from inside the
# container before writing to it — Docker auto-creates ./backups/ as
# root-owned, but SQL Server runs as a fixed non-root UID (10001/mssql)
# inside the container, which can't write into a root-owned directory. Same
# root cause class as the pgAdmin/STT-SCHEDULE UID issue this repo's own
# install_offline.sh already proactively fixes for database/ and scripts/ —
# this directory needs the identical fix, done from inside the container,
# never by chowning the host path directly (its real resolved location
# isn't guaranteed stable across compose revisions).
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec -T -u root sqlserver chown -R 10001:0 /var/opt/mssql/backup

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CONTAINER_BACKUP_FILE="/var/opt/mssql/backup/${DB_NAME}_${TIMESTAMP}.bak"

# MSYS_NO_PATHCONV=1 is a no-op on real Linux — only matters if this is ever
# run from Windows Git Bash, where MSYS otherwise mangles the --workdir
# argument into a Windows-style path and the exec fails outright.
# -b: sqlcmd only exits non-zero on a real T-SQL error inside -i's script
# with this flag set -- without it, a failed BACKUP DATABASE statement
# (e.g. the real WITH COMPRESSION/Express-edition failure this repo hit)
# still returns exit 0, letting this script proceed to `docker compose cp`
# a .bak file that was never actually created -- a real, confirmed
# live failure, 2026-08-25, Pass 4 controlled-failure qualification.
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec -T --workdir /opt/dbpkg/scripts sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$DB_SA_PASSWORD" -C -b \
  -v DB_NAME="$DB_NAME" -v BACKUP_PATH="$CONTAINER_BACKUP_FILE" \
  -i backup_database.sql

if [ -n "${RAH_BACKUP_OUTPUT_PATH:-}" ]; then
  mkdir -p "$(dirname "$RAH_BACKUP_OUTPUT_PATH")"
  MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" cp "sqlserver:${CONTAINER_BACKUP_FILE}" "$RAH_BACKUP_OUTPUT_PATH"
  echo "==> Backup written to ${RAH_BACKUP_OUTPUT_PATH} (Platform-requested path)"
else
  echo "==> Backup written inside container at ${CONTAINER_BACKUP_FILE}"
  echo "==> On the host, this is under ./backups/ (bind-mounted — see compose/docker-compose.yml)"
fi
