#!/usr/bin/env bash
# generate_self_signed_cert.sh
# Generates a self-signed TLS cert/key for nginx, pinned to whatever
# IP/hostname the deployment target actually uses. Re-run this whenever the
# stack moves to a new host — a cert generated for one IP will not validate
# for another (this is exactly what broke the old in-app :3443 cert when the
# app moved off its original host).
#
# Usage: ./generate_self_signed_cert.sh <IP-or-hostname> [more IPs/hostnames...]
# Example: ./generate_self_signed_cert.sh 170.70.32.34 localhost 127.0.0.1
#
# Note for testing on Windows Git Bash: MSYS mangles a leading "/" in -subj
# into a Windows path (e.g. "/CN=..." becomes "C:/Program Files/Git/CN=...").
# Run with `MSYS2_ARG_CONV_EXCL="/CN=" ./generate_self_signed_cert.sh ...`
# there (scoped to just that argument — MSYS_NO_PATHCONV=1 is too broad and
# breaks the -keyout/-out file path arguments in this same command instead).
# The real target (Linux Debian) has no such quirk — do not "fix" this by
# reintroducing a double slash; that just makes OpenSSL skip the CN field.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <IP-or-hostname> [more IPs/hostnames...]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/certs"
mkdir -p "$CERT_DIR"

SAN=""
for entry in "$@"; do
  if [[ "$entry" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SAN="${SAN}IP:${entry},"
  else
    SAN="${SAN}DNS:${entry},"
  fi
done
SAN="${SAN%,}"

openssl req -x509 -nodes -days 825 \
  -newkey rsa:2048 \
  -keyout "$CERT_DIR/key.pem" \
  -out "$CERT_DIR/cert.pem" \
  -subj "/CN=$1/O=RAH Lab/C=LB" \
  -addext "subjectAltName=$SAN"

echo "Generated $CERT_DIR/cert.pem and $CERT_DIR/key.pem for: $SAN"
echo "Restart the nginx container to pick up the new cert."
