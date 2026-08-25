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

echo "==> Step 1/3: Loading Docker images from release/docker-images/..."
# No whisper-model extraction step anymore -- the model is baked into
# whisper.tar at build time (see documentation/RELEASE_NOTES.md's 1.2.0
# section for why), so this release ships no assets/ directory at all.
"$RELEASE_DIR/scripts/load_images.sh"
echo

echo "==> Step 2/3: Starting the stack (this installs the database on first run)..."
"$RELEASE_DIR/scripts/start_stack.sh"

echo "==> Waiting for containers to settle (30s)..."
sleep 30
echo

echo "==> Step 3/3: Verifying installation..."
"$RELEASE_DIR/scripts/verify_installation.sh"

echo
echo "==> Installation complete."
echo "==> Open https://<this-server-IP>/ in a browser (accept the self-signed cert warning)."
echo "==> Log in with admin / admin123 and change the password immediately — see documentation/VALIDATION_CHECKLIST.md."
echo
echo "==> The optional RAG chatbot (Ollama-based) was NOT started -- it's off"
echo "    by default. See documentation/INSTALL_OFFLINE.md 'Enabling the"
echo "    optional RAG chatbot' section if this site has eDelphyn and wants it."
