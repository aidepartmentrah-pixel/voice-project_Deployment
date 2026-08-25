#!/usr/bin/env bash
# install_offline.sh — first-time installation entry point for the offline
# Debian Docker host. Local files only — never touches the internet.
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The Platform runs every lifecycle script in place from Release Storage
# (immutable) — never copies it into the canonical deployment path. RELEASE_DIR
# above therefore always points at Release Storage, not the live deployment.
# DEPLOY_DIR is where the *mutable* state actually lives: Platform's own
# render_configuration() writes the real compose/.env here (passed via
# RAH_ACTIVE_DEPLOYMENT_PATH), and backups/ must persist here too, surviving
# every future update/reinstall even after this exact Release directory is
# long gone. A manual, no-Platform run has no deployment/Release split at
# all, so DEPLOY_DIR falls back to RELEASE_DIR itself, preserving the
# original single-directory behavior unchanged.
DEPLOY_DIR="${RAH_ACTIVE_DEPLOYMENT_PATH:-$RELEASE_DIR}"

echo "==> voice-project (Blood Bank) offline installation"
echo

if [ ! -f "$DEPLOY_DIR/compose/.env" ]; then
  echo "ERROR: $DEPLOY_DIR/compose/.env not found." >&2
  echo "Copy compose/.env.offline.template to compose/.env and fill in real values, then re-run this script." >&2
  exit 1
fi

set -a; source "$DEPLOY_DIR/compose/.env"; set +a
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

# backups/ must live under the real deployment path, not Release Storage
# (which is read-only and disposable) -- see docker-compose.yml's own
# BACKUPS_HOST_PATH comment. Created here so it exists before the first
# backup ever runs; ownership is fixed separately, inside the container,
# by backup_database.sh itself (Docker would otherwise auto-create this as
# root-owned, which SQL Server's own non-root UID can't write into).
mkdir -p "$DEPLOY_DIR/backups"

# database/, scripts/, and the nginx config/certs directory all get
# bind-mounted at runtime (see docker-compose.yml). When DEPLOY_DIR differs
# from RELEASE_DIR (Platform-driven), those bind-mount sources must be real,
# absolute, host-resolvable paths under the deployment path -- Platform's own
# backend runs `docker compose` from inside its own container via the host's
# Docker socket, and a path relative to Release Storage resolves against
# Platform's own container filesystem view, not the real host path the
# Docker daemon needs (confirmed live, 2026-08-25: this silently bind-mounted
# an empty directory for database/scripts, and hard-failed for nginx.conf).
# Copying this content into the deployment path once, here, makes every
# bind-mount source in docker-compose.yml a real, identity-mapped absolute
# path instead. A manual run has DEPLOY_DIR == RELEASE_DIR, so this is a
# same-directory no-op copy, not a behavior change.
echo "==> Copying database/scripts/nginx-config into the deployment path..."
mkdir -p "$DEPLOY_DIR/database" "$DEPLOY_DIR/scripts" "$DEPLOY_DIR/compose/nginx/certs"
cp -r "$RELEASE_DIR/database/." "$DEPLOY_DIR/database/"
cp -r "$RELEASE_DIR/scripts/." "$DEPLOY_DIR/scripts/"
cp "$RELEASE_DIR/compose/nginx/nginx.conf" "$DEPLOY_DIR/compose/nginx/nginx.conf"
cp "$RELEASE_DIR/compose/nginx/generate_self_signed_cert.sh" "$DEPLOY_DIR/compose/nginx/generate_self_signed_cert.sh"
chmod -R o+rX "$DEPLOY_DIR/database" "$DEPLOY_DIR/scripts"
export DEPLOY_DATABASE_PATH="$DEPLOY_DIR/database"
export DEPLOY_SCRIPTS_PATH="$DEPLOY_DIR/scripts"
export DEPLOY_NGINX_CONF_PATH="$DEPLOY_DIR/compose/nginx/nginx.conf"
export DEPLOY_NGINX_CERTS_PATH="$DEPLOY_DIR/compose/nginx/certs"

# A human operator normally runs generate_self_signed_cert.sh manually
# (see documentation/INSTALL_OFFLINE.md) with this server's real IP, for a
# clean cert with no name-mismatch warning. Under a Platform-driven,
# non-interactive install there is no operator session to run that command
# at all -- so if no cert exists yet, generate one automatically with
# generic SANs (still real, working TLS, just an extra name-mismatch
# warning alongside the expected self-signed one until an operator
# re-runs the script for this site's actual IP).
if [ ! -f "$DEPLOY_DIR/compose/nginx/certs/cert.pem" ]; then
  if [ -n "${RAH_ACTIVE_DEPLOYMENT_PATH:-}" ]; then
    echo "==> No TLS cert found -- generating a generic self-signed one for this Platform-driven install..."
    echo "    (re-run scripts/nginx/generate_self_signed_cert.sh with this site's real IP for a clean cert)"
    DETECTED_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    chmod +x "$DEPLOY_DIR/compose/nginx/generate_self_signed_cert.sh"
    "$DEPLOY_DIR/compose/nginx/generate_self_signed_cert.sh" "${DETECTED_IP:-localhost}" localhost 127.0.0.1
  else
    echo "ERROR: No TLS cert found at $DEPLOY_DIR/compose/nginx/certs/." >&2
    echo "Run compose/nginx/generate_self_signed_cert.sh <this-server-IP> first (see documentation/INSTALL_OFFLINE.md)." >&2
    exit 1
  fi
fi

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
echo "==> Open https://<this-server-IP>:${HTTPS_PORT:-443}/ in a browser (accept the self-signed cert warning)."
echo "==> Log in with admin / admin123 and change the password immediately — see documentation/VALIDATION_CHECKLIST.md."
echo
echo "==> The optional RAG chatbot (Ollama-based) was NOT started -- it's off"
echo "    by default. See documentation/INSTALL_OFFLINE.md 'Enabling the"
echo "    optional RAG chatbot' section if this site has eDelphyn and wants it."
