# db-init/Dockerfile
# Minimal image carrying sqlcmd + the Phase 1 database package. Its only job
# is to run scripts/install_database.sh once, then exit — it is not a
# long-running service. Must be built with the REPO ROOT as build context
# (needs database/ and scripts/ from outside this folder).

FROM debian:12-slim

# The https rewrite works around a real, observed engineering-machine
# network issue (plain-http deb.debian.org getting a 403 via its Fastly
# CDN) — same fix already used in python-service/Dockerfile and
# STT-SCHEDULE/backend/Dockerfile. Unlike python:3.11-slim-bookworm (which
# already ships ca-certificates), debian:12-slim ships with NO trust store
# at all, so switching straight to https here is a chicken-and-egg problem:
# apt can't verify deb.debian.org's cert until ca-certificates is installed,
# and it can't install ca-certificates without a verified https connection.
# Bootstrap it with peer verification disabled for this ONE update+install
# (only fetching curl/gnupg2/ca-certificates themselves — nothing else),
# then every apt-get call after that runs with full verification once a
# real trust store exists.
RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/*.sources

RUN apt-get update -o Acquire::https::Verify-Peer=false \
    && apt-get install -y --no-install-recommends -o Acquire::https::Verify-Peer=false \
        curl gnupg2 apt-transport-https ca-certificates \
    && update-ca-certificates \
    && mkdir -p /usr/share/keyrings \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && curl -sSL https://packages.microsoft.com/config/debian/12/prod.list \
        > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends mssql-tools18 unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/opt/mssql-tools18/bin"

WORKDIR /package
COPY database/ ./database/
COPY scripts/ ./scripts/
RUN chmod +x ./scripts/install_database.sh

ENTRYPOINT ["./scripts/install_database.sh"]
