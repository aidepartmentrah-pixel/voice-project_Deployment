#!/usr/bin/env bash
# export_images.sh — runs on the Build Workstation (this laptop), AFTER
# `docker compose build` has succeeded. Tags every image this stack needs
# and saves each as a .tar under release/docker-images/, ready for
# USB/DVD transfer to the offline server.
#
# Includes mcr.microsoft.com/mssql/server and nginx too — even though
# SQL Server images are normally provided by the separate "Offline Debian
# Server Kit," this keeps this app's release self-contained regardless of
# whether that kit has been prepared for this particular offline host yet.
set -euo pipefail

VERSION="${1:-1.0.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/release/docker-images"
mkdir -p "$OUT_DIR"

# Source names come from docker-compose.yml's pinned `name: voice-project-dev`
# — NOT the directory-derived default (voice-project_deployment-*), which is
# stale the moment that pin was added. This bit us once already: a rebuilt
# backend image got silently skipped in favor of a stale same-named image
# left over from before the pin existed. Verify with `docker images` if in
# doubt — the image ID actually being tagged should match your latest build.
docker tag voice-project-dev-backend  "voice-project-backend:${VERSION}"
docker tag voice-project-dev-whisper  "voice-project-whisper:${VERSION}"
docker tag voice-project-dev-db-init  "voice-project-db-init:${VERSION}"

echo "==> Saving voice-project-backend:${VERSION}"
docker save -o "$OUT_DIR/backend.tar" "voice-project-backend:${VERSION}"

echo "==> Saving voice-project-whisper:${VERSION}"
docker save -o "$OUT_DIR/whisper.tar" "voice-project-whisper:${VERSION}"

echo "==> Saving voice-project-db-init:${VERSION}"
docker save -o "$OUT_DIR/db-init.tar" "voice-project-db-init:${VERSION}"

echo "==> Saving mcr.microsoft.com/mssql/server:2022-latest"
docker save -o "$OUT_DIR/sqlserver.tar" "mcr.microsoft.com/mssql/server:2022-latest"

echo "==> Saving nginx:1.27-alpine"
docker save -o "$OUT_DIR/nginx.tar" "nginx:1.27-alpine"

echo "==> Done. Contents of $OUT_DIR:"
ls -lh "$OUT_DIR"
