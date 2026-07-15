#!/usr/bin/env bash
# backup_database.sh — full BloodBankDB backup to ./backups/ (host-side,
# survives container recreation).
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RELEASE_DIR/compose"
[ -f .env ] && { set -a; source .env; set +a; }

: "${DB_NAME:?DB_NAME is required (set in compose/.env)}"
: "${DB_SA_PASSWORD:?DB_SA_PASSWORD is required (set in compose/.env)}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="/var/opt/mssql/backup/${DB_NAME}_${TIMESTAMP}.bak"

# MSYS_NO_PATHCONV=1 is a no-op on real Linux — only matters if this is ever
# run from Windows Git Bash, where MSYS otherwise mangles the --workdir
# argument into a Windows-style path and the exec fails outright.
MSYS_NO_PATHCONV=1 docker compose exec -T --workdir /opt/dbpkg/scripts sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$DB_SA_PASSWORD" -C \
  -v DB_NAME="$DB_NAME" -v BACKUP_PATH="$BACKUP_FILE" \
  -i backup_database.sql

echo "==> Backup written inside container at ${BACKUP_FILE}"
echo "==> On the host, this is under ./backups/ (bind-mounted — see compose/docker-compose.yml)"
