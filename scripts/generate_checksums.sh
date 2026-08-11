#!/usr/bin/env bash
# generate_checksums.sh — SHA-256 checksums for every file in the release
# package, so an operator can verify DVD/USB transfer integrity before
# installing. Run on the Build Workstation after export_images.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$REPO_ROOT/release"
OUT_FILE="$RELEASE_DIR/checksums/release_hashes.txt"

cd "$RELEASE_DIR"
{
  echo "# SHA-256 checksums — voice-project release package"
  echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "# Verify with: sha256sum -c release_hashes.txt (run from inside release/)"
  echo
  find . -type f \
    ! -path "./checksums/*" \
    ! -name ".env" \
    -exec sha256sum {} \; | sed 's#^\(\S*\)  \./#\1  #'
} > "$OUT_FILE"

echo "==> Wrote $(wc -l < "$OUT_FILE") lines to $OUT_FILE"
