# python-service/Dockerfile — Flask + faster-whisper transcription service.
# Preserves the existing Flask implementation as-is (RAH Lab's FastAPI
# standard does not apply retroactively to this pre-existing project).
#
# Deliberately does NOT bake a model into the image (that was tried in an
# earlier version and caused a real bug: whatever WHISPER_MODEL size was
# set at BUILD time got cached, but the RUNTIME env var could specify a
# different size — a cache miss then triggered a live huggingface.co
# download, which fails hard on an air-gapped host). The model is instead
# supplied entirely via a mounted volume at runtime (WHISPER_MODEL_PATH) —
# see scripts/export_whisper_model.sh and docker-compose.yml. This keeps
# exactly one source of truth for "which model is actually available."

FROM python:3.11-slim-bookworm

# ffmpeg is required at runtime — whisper_service.py shells out to it via
# subprocess for audio normalization before transcription.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY whisper_service.py .

RUN useradd --create-home --shell /bin/false appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 5001

CMD ["python", "whisper_service.py"]
