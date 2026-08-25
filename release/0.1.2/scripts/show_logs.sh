#!/usr/bin/env bash
# show_logs.sh — tails logs for all services, or one service if named.
# Usage: ./show_logs.sh [service-name]
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="${RAH_ACTIVE_DEPLOYMENT_PATH:-$RELEASE_DIR}"
cd "$RELEASE_DIR/compose"

export BACKUPS_HOST_PATH="$DEPLOY_DIR/backups"
export DEPLOY_DATABASE_PATH="$DEPLOY_DIR/database"
export DEPLOY_SCRIPTS_PATH="$DEPLOY_DIR/scripts"
export DEPLOY_NGINX_CONF_PATH="$DEPLOY_DIR/compose/nginx/nginx.conf"
export DEPLOY_NGINX_CERTS_PATH="$DEPLOY_DIR/compose/nginx/certs"

if [ "$#" -ge 1 ]; then
  docker compose --env-file "$DEPLOY_DIR/compose/.env" logs -f --tail=200 "$1"
else
  docker compose --env-file "$DEPLOY_DIR/compose/.env" logs -f --tail=200
fi
