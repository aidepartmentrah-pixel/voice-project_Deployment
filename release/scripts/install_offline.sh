#!/usr/bin/env bash
# install_offline.sh — first-time installation entry point for the offline
# Debian Docker host. Local files only — never touches the internet.
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> voice-project (Blood Bank) offline installation"
echo

if [ ! -f "$RELEASE_DIR/compose/.env" ]; then
  echo "ERROR: compose/.env not found." >&2
  echo "Copy compose/.env.offline.template to compose/.env and fill in real values, then re-run this script." >&2
  exit 1
fi

set -a; source "$RELEASE_DIR/compose/.env"; set +a
source "$RELEASE_DIR/scripts/_preflight_checks.sh"
run_preflight_checks

# database/ and scripts/ are bind-mounted read-only into the sqlserver
# container (see compose/docker-compose.yml) so verify_installation.sh/
# backup_database.sh/restore_database.sh can exec sqlcmd against them. That
# container runs as a fixed non-root UID — if these directories are left at
# whatever restrictive mode they were extracted/copied with (e.g. 700,
# owner-only), that UID can't even open them, and sqlcmd fails with
# "Invalid filename" — not a path problem, a permission denial wearing the
# same error text. Same root cause class as the pgAdmin non-root-UID
# permission issue on STT-SCHEDULE; same fix, applied here too. o+rX only
# (read + traverse for "others"), never write.
echo "==> Ensuring database/ and scripts/ are readable by the sqlserver container's UID..."
chmod -R o+rX "$RELEASE_DIR/database" "$RELEASE_DIR/scripts"
echo

echo "==> Step 1/4: Extracting the Whisper model asset (no internet needed — local file only)..."
MODEL_DIR="$RELEASE_DIR/assets/whisper-model-medium"
MODEL_ZIP="$RELEASE_DIR/assets/whisper-model-medium.zip"
if [ -d "$MODEL_DIR" ] && [ -f "$MODEL_DIR/model.bin" ]; then
  echo "    Already extracted at $MODEL_DIR — skipping."
elif [ -f "$MODEL_ZIP" ]; then
  mkdir -p "$MODEL_DIR"
  unzip -q -o "$MODEL_ZIP" -d "$RELEASE_DIR/assets"
  echo "    Extracted to $MODEL_DIR"
else
  echo "ERROR: $MODEL_ZIP not found. The release package is incomplete — the whisper" >&2
  echo "container cannot start without it (see documentation/TROUBLESHOOTING.md)." >&2
  exit 1
fi
echo

echo "==> Step 2/4: Loading Docker images from release/docker-images/..."
"$RELEASE_DIR/scripts/load_images.sh"
echo

echo "==> Step 3/4: Starting the stack (this installs the database on first run)..."
"$RELEASE_DIR/scripts/start_stack.sh"

echo "==> Waiting for containers to settle (30s)..."
sleep 30
echo

echo "==> Step 4/4: Verifying installation..."
"$RELEASE_DIR/scripts/verify_installation.sh"

echo
echo "==> Installation complete."
echo "==> Open https://<this-server-IP>/ in a browser (accept the self-signed cert warning)."
echo "==> Log in with admin / admin123 and change the password immediately — see documentation/VALIDATION_CHECKLIST.md."
