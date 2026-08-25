#!/usr/bin/env bash
# verify_installation.sh — post-install/post-update health check.
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="${RAH_ACTIVE_DEPLOYMENT_PATH:-$RELEASE_DIR}"
cd "$RELEASE_DIR/compose"

if [ -f "$DEPLOY_DIR/compose/.env" ]; then
  set -a; source "$DEPLOY_DIR/compose/.env"; set +a
fi
COMPOSE=(docker compose --env-file "$DEPLOY_DIR/compose/.env")
export BACKUPS_HOST_PATH="$DEPLOY_DIR/backups"
export DEPLOY_DATABASE_PATH="$DEPLOY_DIR/database"
export DEPLOY_SCRIPTS_PATH="$DEPLOY_DIR/scripts"
export DEPLOY_NGINX_CONF_PATH="$DEPLOY_DIR/compose/nginx/nginx.conf"
export DEPLOY_NGINX_CERTS_PATH="$DEPLOY_DIR/compose/nginx/certs"

echo "==> Container status:"
"${COMPOSE[@]}" ps
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
if MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec -T --workdir /opt/dbpkg/scripts sqlserver /opt/mssql-tools18/bin/sqlcmd \
     -S localhost -d "${DB_NAME:-BloodBankDB}" -U sa -P "${DB_SA_PASSWORD:?DB_SA_PASSWORD not set}" -C -b \
     -v DB_NAME="${DB_NAME:-BloodBankDB}" -i verify_database.sql; then
  echo "==> Database checks OK."
else
  echo "==> DATABASE CHECKS FAILED." >&2
  FAIL=1
fi
echo

echo "==> Checking backend health..."
# Exec into the backend container directly (matching the already-correct
# database check above, and the backend service's own Compose healthcheck
# command) rather than a raw `curl https://localhost/...` from the host.
# This script may be invoked by the RAH Offline Installation Platform,
# which runs lifecycle scripts as a subprocess of its own backend process
# — potentially inside a container with its own isolated Docker network,
# distinct from this host's. A host-network curl that works fine run by
# hand can silently fail from there even when the app is genuinely
# healthy, since "localhost" means something different to the caller in
# that case. docker compose exec reaches the target container directly
# via the Docker socket regardless of the caller's own network namespace.
if "${COMPOSE[@]}" exec -T backend node -e "require('http').get('http://localhost:3000/mode-check', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"; then
  echo "==> Backend is reachable and healthy."
else
  echo "==> BACKEND HEALTH CHECK FAILED." >&2
  FAIL=1
fi
echo

echo "==> Checking optional RAG chatbot (Ollama) status..."
# Optional, profile-gated -- skip silently (not a failure) if the profile
# was never enabled at this site. Detected by whether the "ollama" service
# is running at all, not by probing /api/rag-chat directly: that route
# requires an authenticated request (see server.js's requireAuth), so an
# unauthenticated status-code probe can't cleanly distinguish "not enabled"
# from "enabled but broken" -- Docker's own healthcheck status (defined on
# the ollama service in docker-compose.yml) is a more reliable signal.
if "${COMPOSE[@]}" ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx "ollama"; then
  OLLAMA_HEALTH="$("${COMPOSE[@]}" ps --format '{{.Service}} {{.Health}}' 2>/dev/null | awk '$1=="ollama"{print $2}')"
  if [ "$OLLAMA_HEALTH" = "healthy" ]; then
    echo "==> Ollama is running and healthy."
  else
    echo "==> OLLAMA CHECK FAILED (container running but health status: ${OLLAMA_HEALTH:-unknown})." >&2
    FAIL=1
  fi
  if "${COMPOSE[@]}" ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx "rag-chatbot"; then
    echo "==> rag-chatbot container is running."
  else
    echo "==> RAG CHATBOT CHECK FAILED (ollama is up but rag-chatbot is not)." >&2
    FAIL=1
  fi
else
  echo "==> RAG chatbot profile not enabled -- skipping (expected/fine if this site doesn't use it)."
fi

if [ "$FAIL" -eq 0 ]; then
  echo "==> Installation verified — application is healthy."
else
  echo "==> One or more checks failed — see TROUBLESHOOTING.md." >&2
  exit 1
fi
