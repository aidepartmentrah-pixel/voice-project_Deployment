#!/usr/bin/env bash
# verify_installation.sh — post-install/post-update health check.
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RELEASE_DIR/compose"

if [ -f .env ]; then
  set -a; source .env; set +a
fi

echo "==> Container status:"
docker compose ps
echo

FAIL=0

echo "==> Checking database validation..."
# --workdir /opt/dbpkg/scripts matters: verify_database.sql's own ":r
# ../database/sqlserver/validation/validate_*.sql" includes are resolved by
# sqlcmd relative to its CURRENT WORKING DIRECTORY (a sqlcmd quirk, not
# relative to the referencing file) — /opt/dbpkg/scripts and
# /opt/dbpkg/database are mounted as siblings in docker-compose.yml
# specifically so this resolves correctly.
# MSYS_NO_PATHCONV=1 is a no-op on real Linux — only matters if this is ever
# run from Windows Git Bash, where MSYS otherwise mangles the --workdir
# argument into a Windows-style path and the exec fails outright.
if MSYS_NO_PATHCONV=1 docker compose exec -T --workdir /opt/dbpkg/scripts sqlserver /opt/mssql-tools18/bin/sqlcmd \
     -S localhost -d "${DB_NAME:-BloodBankDB}" -U sa -P "${DB_SA_PASSWORD:?DB_SA_PASSWORD not set}" -C \
     -v DB_NAME="${DB_NAME:-BloodBankDB}" -i verify_database.sql; then
  echo "==> Database checks OK."
else
  echo "==> DATABASE CHECKS FAILED." >&2
  FAIL=1
fi
echo

echo "==> Checking backend health through nginx..."
if curl -sk -o /dev/null -w "%{http_code}" https://localhost/health | grep -q "200"; then
  echo "==> Backend is reachable and healthy."
else
  echo "==> BACKEND HEALTH CHECK FAILED." >&2
  FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "==> Installation verified — application is healthy."
else
  echo "==> One or more checks failed — see TROUBLESHOOTING.md." >&2
  exit 1
fi
