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
# If the optional RAG chatbot was already enabled at this site (an "ollama"
# container exists from a previous install/update), carry that forward
# automatically -- a bare `docker compose up -d` without --profile would
# otherwise leave ollama/rag-chatbot on their old images without updating
# them, since profile-gated services aren't included by default.
if docker compose ps -a --format '{{.Service}}' 2>/dev/null | grep -qx "ollama"; then
  echo "    (RAG chatbot profile was previously enabled at this site — updating it too.)"
  docker compose --profile rag-chatbot up -d
else
  docker compose up -d
fi

echo "==> Waiting for containers to settle (20s)..."
sleep 20
"$RELEASE_DIR/scripts/verify_installation.sh"

echo "==> Update complete."
