#!/usr/bin/env bash
# install_database.sh
# First-time SQL Server Database Package installer for BloodBankDB (voice-project).
# Intended to run inside the Docker "db-init" service (Phase 2), but works
# standalone against any reachable SQL Server too.
#
# Required environment variables (never hardcode these):
#   DB_SERVER, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SA_PASSWORD
#
# DB_SA_PASSWORD authenticates as "sa" for 001_create_database.sql only — a
# fresh SQL Server container has no DB_USER login yet, so nothing else can
# create one. Every script after 001, and node-backend itself at runtime,
# uses DB_USER/DB_PASSWORD exclusively. DB_SA_PASSWORD is never read by the
# application — only by this installer.
#
# Safe to re-run: every install script is idempotent (IF NOT EXISTS guards),
# so re-running this against an already-installed database is a no-op.

set -euo pipefail

: "${DB_SERVER:?DB_SERVER is required}"
: "${DB_PORT:=1433}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${DB_SA_PASSWORD:?DB_SA_PASSWORD is required (used only to bootstrap the DB_USER login on a fresh SQL Server container)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="$REPO_ROOT/database/sqlserver/install"

SA_SQLCMD="sqlcmd -S ${DB_SERVER},${DB_PORT} -U sa -P ${DB_SA_PASSWORD} -C -b"

echo "==> Waiting for SQL Server at ${DB_SERVER}:${DB_PORT}..."
for i in $(seq 1 30); do
  if $SA_SQLCMD -Q "SELECT 1" >/dev/null 2>&1; then
    echo "==> SQL Server is reachable."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: SQL Server did not become reachable in time." >&2
    exit 1
  fi
  sleep 2
done

echo "==> 001_create_database.sql (as sa — creates ${DB_NAME} and the ${DB_USER} login if needed)"
$SA_SQLCMD -v DB_NAME="${DB_NAME}" -v APP_USER="${DB_USER}" -v APP_PASSWORD="${DB_PASSWORD}" \
  -i "$INSTALL_DIR/001_create_database.sql"

for f in 002_create_schema.sql 003_create_indexes.sql 004_create_constraints.sql \
         005_create_views.sql 006_create_stored_procedures.sql 007_create_triggers.sql \
         008_seed_lookup_data.sql 009_seed_configuration.sql 010_seed_users_roles.sql \
         011_record_database_version.sql; do
  echo "==> ${f} (against ${DB_NAME}, as sa)"
  $SA_SQLCMD -d "${DB_NAME}" -i "$INSTALL_DIR/$f"
done

echo "==> Verifying installation"
# verify_database.sql uses sqlcmd's :r with paths relative to the CURRENT
# WORKING DIRECTORY (a sqlcmd quirk — :r is not relative to the referencing
# file), so cd into scripts/ before invoking it.
(cd "$REPO_ROOT/scripts" && $SA_SQLCMD -d "${DB_NAME}" -v DB_NAME="${DB_NAME}" -i verify_database.sql)

echo "==> Database installation complete."
