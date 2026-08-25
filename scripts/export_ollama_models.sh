#!/usr/bin/env bash
# export_ollama_models.sh
# Runs on the ONLINE Build Workstation (needs internet the first time this
# pulls a fresh cache; the two required models are ~3GB combined). Pulls
# nomic-embed-text + phi3:mini into assets/ollama-models/ using a throwaway
# container running the plain upstream ollama/ollama image, then docker cp's
# the container's own model store out — this deliberately does NOT
# bind-mount the output directory directly for the write side (see
# export_whisper_model.sh's comment for the exact Docker Desktop Windows/
# WSL2 rename-across-mount-boundary bug this avoids; Ollama's own
# blob-finalization step does the same kind of atomic rename that triggered
# it for faster_whisper's download_model(), so the same failure class is
# expected here too).
#
# Usage: ./export_ollama_models.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/assets/ollama-models"
BASE_IMAGE="ollama/ollama:0.32.13"   # keep in sync with ollama/Dockerfile's FROM line

echo "==> Pulling '${BASE_IMAGE}' (if not already local)..."
docker pull "$BASE_IMAGE"

mkdir -p "$OUT_DIR"

CONTAINER_NAME="ollama-model-export-$$"
echo "==> Starting scratch Ollama server container..."
docker run -d --name "$CONTAINER_NAME" "$BASE_IMAGE" >/dev/null

echo "==> Waiting for the Ollama API to come up..."
for i in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" ollama list >/dev/null 2>&1; then break; fi
  sleep 1
done

echo "==> Pulling nomic-embed-text and phi3:mini inside the container..."
docker exec "$CONTAINER_NAME" ollama pull nomic-embed-text
docker exec "$CONTAINER_NAME" ollama pull phi3:mini

echo "==> Copying the container's own model store out to ${OUT_DIR}..."
docker cp "$CONTAINER_NAME:/root/.ollama/models/." "$OUT_DIR/"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

echo "==> Done. Contents of ${OUT_DIR}:"
du -sh "$OUT_DIR"/* 2>/dev/null || true

echo
echo "==> Zipping for release packaging (Python's zipfile module, same"
echo "    approach as export_whisper_model.sh, to guarantee forward-slash"
echo "    entry names — the ollama/ollama base image has no Python, so this"
echo "    step uses a small python:3.11-slim container instead. Reading via"
echo "    a read-only bind mount is fine here — only WRITING/renaming across"
echo "    the Windows/WSL2 mount boundary hits the bug this script avoids"
echo "    elsewhere; the output file (/tmp/out.zip) is written to the"
echo "    zip container's own filesystem, not the mount)..."
mkdir -p "$REPO_ROOT/release/assets"
ZIP_PATH="$REPO_ROOT/release/assets/ollama-models.zip"

ZIP_CONTAINER="ollama-zip-export-$$"
MSYS_NO_PATHCONV=1 docker run --name "$ZIP_CONTAINER" \
  -v "$OUT_DIR:/src:ro" \
  --entrypoint python3 \
  python:3.11-slim \
  -c "
import zipfile, os
src = '/src'
with zipfile.ZipFile('/tmp/out.zip', 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(src):
        for f in files:
            full = os.path.join(root, f)
            arcname = 'ollama-models/' + os.path.relpath(full, src).replace(os.sep, '/')
            zf.write(full, arcname)
print('zip built inside container')
"
docker cp "$ZIP_CONTAINER:/tmp/out.zip" "$ZIP_PATH"
docker rm "$ZIP_CONTAINER" >/dev/null

echo "==> Wrote $ZIP_PATH"
echo "==> Verifying archive uses forward slashes and the expected top-level folder..."
MSYS_NO_PATHCONV=1 docker run --rm -v "$REPO_ROOT/release/assets:/z:ro" --entrypoint python3 python:3.11-slim -c "
import zipfile
with zipfile.ZipFile('/z/ollama-models.zip') as zf:
    names = zf.namelist()
    assert all('\\\\' not in n for n in names), 'backslash found in zip entry names!'
    assert all(n.startswith('ollama-models/') for n in names), 'unexpected top-level entry'
    print(f'OK - {len(names)} entries, all forward-slash, all under ollama-models/')
"
