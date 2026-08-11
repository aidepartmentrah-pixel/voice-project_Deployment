#!/usr/bin/env bash
# start_stack.sh — starts the full stack via Docker Compose.
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RELEASE_DIR/compose"

if [ ! -f .env ]; then
  echo "ERROR: compose/.env not found. Copy .env.offline.template to .env and fill in real values first." >&2
  exit 1
fi

set -a; source .env; set +a
source "$RELEASE_DIR/scripts/_preflight_checks.sh"
run_preflight_checks

# See install_offline.sh for why: database/ and scripts/ are bind-mounted
# read-only into the sqlserver container, which runs as a fixed non-root
# UID — repeated here so this still holds for anyone starting the stack
# directly (e.g. after a host reboot) without re-running install_offline.sh.
chmod -R o+rX "$RELEASE_DIR/database" "$RELEASE_DIR/scripts"

docker compose up -d
echo "==> Stack starting. Run scripts/verify_installation.sh once containers report healthy."
