# ollama/Dockerfile — Ollama server with nomic-embed-text + phi3:mini baked
# in. Optional service (see docker-compose.yml's "rag-chatbot" profile) —
# not started by a bare `docker compose up`.
#
# RAH platform rule (Runtime Self-Containment): every application-owned
# runtime artifact must be inside the image at build time, not supplied via
# a runtime bind mount. Mirrors python-service/Dockerfile's whisper-model
# baking pattern: models are downloaded ONCE on the online Build Workstation
# via scripts/export_ollama_models.sh, the result lands in
# assets/ollama-models/ (gitignored — see .gitignore; Ollama's model store
# is pure content-addressable blobs, no small-metadata/large-binary split
# like Whisper's export has, so nothing under it is tracked in git), and
# this Dockerfile does a plain COPY. No `ollama pull` at `docker build` time
# — that would require network access during the build itself, which breaks
# reproducibility and is impossible on an air-gapped rebuild.
#
# Base image is the official upstream ollama/ollama — confirmed it runs as
# root by default (HOME=/root, no non-root user configured upstream).
# Shipped as-is (root) rather than guessing at a non-root UID that might
# break the model directory's permissions or a future GPU passthrough path
# — a deliberate, documented exception to this project's usual non-root
# convention (see python-service/Dockerfile, node-backend/Dockerfile).
#
# Build context is the repo root (see docker-compose.yml) so this can reach
# ../assets/ollama-models.

FROM ollama/ollama:0.32.13

COPY assets/ollama-models /models/ollama

ENV OLLAMA_MODELS=/models/ollama
ENV OLLAMA_HOST=0.0.0.0:11434

EXPOSE 11434

# No CMD/ENTRYPOINT override — the upstream image's own entrypoint
# (`ollama serve`) is correct as-is; only the model store path changes.
