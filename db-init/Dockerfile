# db-init/Dockerfile
# Minimal image carrying sqlcmd + the Phase 1 database package. Its only job
# is to run scripts/install_database.sh once, then exit — it is not a
# long-running service. Must be built with the REPO ROOT as build context
# (needs database/ and scripts/ from outside this folder).

FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl gnupg2 apt-transport-https ca-certificates \
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
