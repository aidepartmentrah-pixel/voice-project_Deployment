# python-service/Dockerfile — Flask + faster-whisper transcription service.
# Preserves the existing Flask implementation as-is (RAH Lab's FastAPI
# standard does not apply retroactively to this pre-existing project).
#
# Bakes the model into the image at a fixed path (RAH platform rule: every
# runtime dependency must already be inside the image when `docker build`
# finishes — see docs/decisions/packager-responsibility-boundaries.md in
# Air-Gapped-System-Platform). This does NOT reintroduce the bug an earlier
# version hit (a build-time/runtime WHISPER_MODEL size mismatch triggering a
# live huggingface.co download): whisper_service.py already treats
# WHISPER_MODEL_PATH as authoritative whenever it's set, and it stays
# pointed at this same baked-in path permanently — WHISPER_MODEL (the
# size-name that can trigger a download) is only ever consulted as a
# fallback when WHISPER_MODEL_PATH is unset, which it never is here. Build
# context is the repo root (see docker-compose.yml), matching the pattern
# node-backend/db-init already use, so this Dockerfile can reach ../assets/.

FROM python:3.11-slim-bookworm

# ffmpeg is required at runtime — whisper_service.py shells out to it via
# subprocess for audio normalization before transcription.
# The https rewrite works around a real, observed engineering-machine
# network issue (plain-http deb.debian.org getting a 403 via its Fastly
# CDN) — same fix already used in STT-SCHEDULE/backend/Dockerfile.
RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/*.sources \
    && apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY python-service/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY python-service/whisper_service.py .
COPY assets/whisper-model-medium /models/whisper-medium

RUN useradd --create-home --shell /bin/false appuser \
    && chown -R appuser:appuser /app /models
USER appuser

EXPOSE 5001

CMD ["python", "whisper_service.py"]
