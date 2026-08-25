#!/usr/bin/env bash
# start_stack.sh — starts the full stack via Docker Compose.
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="${RAH_ACTIVE_DEPLOYMENT_PATH:-$RELEASE_DIR}"
cd "$RELEASE_DIR/compose"

if [ ! -f "$DEPLOY_DIR/compose/.env" ]; then
  echo "ERROR: $DEPLOY_DIR/compose/.env not found. Copy .env.offline.template to .env and fill in real values first." >&2
  exit 1
fi

set -a; source "$DEPLOY_DIR/compose/.env"; set +a
source "$RELEASE_DIR/scripts/_preflight_checks.sh"
run_preflight_checks

# See install_offline.sh for why: database/ and scripts/ are bind-mounted
# read-only into the sqlserver container, which runs as a fixed non-root
# UID — repeated here so this still holds for anyone starting the stack
# directly (e.g. after a host reboot) without re-running install_offline.sh.
chmod -R o+rX "$RELEASE_DIR/database" "$RELEASE_DIR/scripts"
mkdir -p "$DEPLOY_DIR/backups"

# database/scripts/nginx-config must be real, deployment-path copies, not
# Release-Storage-relative paths -- see docker-compose.yml's own
# DEPLOY_DATABASE_PATH comment. install_offline.sh/update_offline.sh are
# the ones that actually copy this content; this just re-points compose at
# it for a standalone start (e.g. after a host reboot).
export BACKUPS_HOST_PATH="$DEPLOY_DIR/backups"
export DEPLOY_DATABASE_PATH="$DEPLOY_DIR/database"
export DEPLOY_SCRIPTS_PATH="$DEPLOY_DIR/scripts"
export DEPLOY_NGINX_CONF_PATH="$DEPLOY_DIR/compose/nginx/nginx.conf"
export DEPLOY_NGINX_CERTS_PATH="$DEPLOY_DIR/compose/nginx/certs"

docker compose --env-file "$DEPLOY_DIR/compose/.env" up -d
echo "==> Stack starting. Run scripts/verify_installation.sh once containers report healthy."
