# rag-chatbot/Dockerfile — Flask RAG chatbot over the blood bank's eDelphyn
# data snapshot. Optional service (see docker-compose.yml's "rag-chatbot"
# profile) — not started by a bare `docker compose up`.
#
# Mirrors python-service/Dockerfile's base image and Debian https-rewrite
# fix (same real, observed 403 this network's proxy returns for plain-HTTP
# deb.debian.org via its Fastly CDN). Build context is the repo root (see
# docker-compose.yml), matching every other Dockerfile in this project.

FROM python:3.11-slim-bookworm

RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/*.sources

WORKDIR /app

COPY rag-chatbot/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY rag-chatbot/*.py ./
COPY rag-chatbot/static/ ./static/
COPY rag-chatbot/docker-entrypoint.sh ./docker-entrypoint.sh

RUN chmod +x ./docker-entrypoint.sh \
    && useradd --create-home --shell /bin/false appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 5000

ENTRYPOINT ["./docker-entrypoint.sh"]
