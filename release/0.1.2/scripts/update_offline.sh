#!/usr/bin/env bash
# update_offline.sh — updates an existing installation to a new release.
# Preserves the database and uploaded files (named volumes untouched).
#
# Both confirmation prompts below are skipped automatically when
# RAH_ACTIVE_DEPLOYMENT_PATH is set — the signal this Release's other
# scripts already use to detect a Platform-driven (non-interactive)
# invocation. A manual run keeps both prompts unchanged. Platform itself
# already runs a mandatory backup before invoking this script at all (per
# the Backup-Before-Update Rule), so skipping the first prompt there isn't
# skipping the backup, only the redundant manual confirmation of it. Same
# pattern as the interactive-prompt fix already applied to STT-SCHEDULE's
# restore_database.sh (Bug 3's own documented sub-finding) — see
# docs/development/Bugs/Bug 3 — Backup Path Contract Not Honored.md in
# the Air-Gapped-System-Platform repo.
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="${RAH_ACTIVE_DEPLOYMENT_PATH:-$RELEASE_DIR}"

echo "==> voice-project (Blood Bank) offline update"
echo

if [ -z "${RAH_ACTIVE_DEPLOYMENT_PATH:-}" ]; then
  echo "==> Before continuing, have you backed up the database? (scripts/backup_database.sh)"
  read -r -p "    Type 'yes' to continue: " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted. Run scripts/backup_database.sh first."
    exit 1
  fi
fi

echo "==> Step 1/3: Loading new Docker images..."
"$RELEASE_DIR/scripts/load_images.sh"
echo

if [ -z "${RAH_ACTIVE_DEPLOYMENT_PATH:-}" ]; then
  echo "==> Step 2/3: Apply any new migrations manually first if this release's"
  echo "    RELEASE_NOTES.md lists new files under database/sqlserver/migrations/."
  echo "    Press Enter once done (or if there are none this release)."
  read -r
  echo
else
  echo "==> Step 2/3: (Platform-driven run — no interactive migration prompt."
  echo "    This Release currently ships no numbered migration files; a future"
  echo "    Release that adds real ones needs a real, non-interactive migration"
  echo "    entrypoint, not this prompt.)"
fi

echo "==> Step 3/3: Restarting the stack with the new images..."
cd "$RELEASE_DIR/compose"

# Refresh database/scripts/nginx.conf from this (possibly newer) Release
# into the deployment path -- see docker-compose.yml's own
# DEPLOY_DATABASE_PATH comment for why these must be real, absolute,
# deployment-path copies rather than Release-Storage-relative paths.
# Certs are deliberately NOT touched here -- generated once at install,
# preserved across updates.
mkdir -p "$DEPLOY_DIR/database" "$DEPLOY_DIR/scripts" "$DEPLOY_DIR/compose/nginx/certs"
cp -r "$RELEASE_DIR/database/." "$DEPLOY_DIR/database/"
cp -r "$RELEASE_DIR/scripts/." "$DEPLOY_DIR/scripts/"
cp "$RELEASE_DIR/compose/nginx/nginx.conf" "$DEPLOY_DIR/compose/nginx/nginx.conf"
chmod -R o+rX "$DEPLOY_DIR/database" "$DEPLOY_DIR/scripts"
export BACKUPS_HOST_PATH="$DEPLOY_DIR/backups"
export DEPLOY_DATABASE_PATH="$DEPLOY_DIR/database"
export DEPLOY_SCRIPTS_PATH="$DEPLOY_DIR/scripts"
export DEPLOY_NGINX_CONF_PATH="$DEPLOY_DIR/compose/nginx/nginx.conf"
export DEPLOY_NGINX_CERTS_PATH="$DEPLOY_DIR/compose/nginx/certs"

# If the optional RAG chatbot was already enabled at this site (an "ollama"
# container exists from a previous install/update), carry that forward
# automatically -- a bare `docker compose up -d` without --profile would
# otherwise leave ollama/rag-chatbot on their old images without updating
# them, since profile-gated services aren't included by default.
if docker compose --env-file "$DEPLOY_DIR/compose/.env" ps -a --format '{{.Service}}' 2>/dev/null | grep -qx "ollama"; then
  echo "    (RAG chatbot profile was previously enabled at this site — updating it too.)"
  docker compose --env-file "$DEPLOY_DIR/compose/.env" --profile rag-chatbot up -d
else
  docker compose --env-file "$DEPLOY_DIR/compose/.env" up -d
fi

echo "==> Waiting for containers to settle (20s)..."
sleep 20
"$RELEASE_DIR/scripts/verify_installation.sh"

echo "==> Update complete."
