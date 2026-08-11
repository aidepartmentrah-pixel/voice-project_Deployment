#!/usr/bin/env bash
# update_offline.sh — updates an existing installation to a new release.
# Preserves the database and uploaded files (named volumes untouched).
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> voice-project (Blood Bank) offline update"
echo
echo "==> Before continuing, have you backed up the database? (scripts/backup_database.sh)"
read -r -p "    Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted. Run scripts/backup_database.sh first."
  exit 1
fi

echo "==> Step 1/3: Loading new Docker images..."
"$RELEASE_DIR/scripts/load_images.sh"
echo

echo "==> Step 2/3: Apply any new migrations manually first if this release's"
echo "    RELEASE_NOTES.md lists new files under database/sqlserver/migrations/."
echo "    Press Enter once done (or if there are none this release)."
read -r
echo

echo "==> Step 3/3: Restarting the stack with the new images..."
cd "$RELEASE_DIR/compose"
docker compose up -d

echo "==> Waiting for containers to settle (20s)..."
sleep 20
"$RELEASE_DIR/scripts/verify_installation.sh"

echo "==> Update complete."
