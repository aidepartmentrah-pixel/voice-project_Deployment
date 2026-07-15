# Portainer Deployment Guide

For operators who prefer managing this stack through Portainer's web UI
instead of the command line.

## Prerequisite

Portainer CE is already installed on the offline server (per the Offline
Debian Server Kit). This guide assumes it's reachable at
`https://<server-ip>:9443`.

## Step 1 — Confirm images are loaded

Images must be loaded via `./scripts/load_images.sh` (or manually,
`docker load -i release/docker-images/<name>.tar`) **before** creating the
stack — Portainer cannot pull them from Docker Hub on an offline server.

In Portainer: **Images** (left sidebar) → confirm you see
`voice-project-backend`, `voice-project-whisper`, `voice-project-db-init`,
`mcr.microsoft.com/mssql/server`, and `nginx` listed.

## Step 2 — Create the stack

1. **Stacks** → **Add stack**.
2. Name it `voice-project`.
3. **Web editor** → paste the contents of `release/compose/docker-compose.yml`.
4. Under **Environment variables**, add every variable from your filled-in
   `.env` (`DB_SERVER`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`,
   `DB_SA_PASSWORD`, `JWT_SECRET`, `WHISPER_SERVICE_URL`, `WHISPER_MODEL`) —
   either paste them one by one, or use Portainer's "Load variables from
   .env file" upload option if your version supports it.
5. Click **Deploy the stack**.

## Step 3 — Watch it come up

**Stacks** → `voice-project` → you'll see all 5 containers. `db-init`
will show as **Exited (0)** once it finishes — that's success, not a
failure (it's a one-shot job, not a long-running service). If it shows a
non-zero exit code, click it → **Logs** to see why.

## Step 4 — View logs

**Containers** → click a container name → **Logs** tab. Useful ones:
`voice-project-backend-1`, `voice-project-db-init-1`.

## Step 5 — Restart / stop services

**Containers** → select checkbox(es) → **Restart** / **Stop** at the top of
the list. Or manage the whole stack at once from **Stacks** →
`voice-project` → **Stop this stack** / **Start this stack**.

## Step 6 — Confirm SQL Server is running

**Containers** → `voice-project-sqlserver-1` → status should read
**running (healthy)**. If it says **running (unhealthy)** or **starting**
for more than a minute, click into **Logs** to check for a startup error
(usually a password complexity issue on first boot).

## Updating via Portainer

**Stacks** → `voice-project` → **Editor** tab → if the compose file itself
changed, paste the new version → **Update the stack**. If only image
contents changed (same compose file, new build), instead: **Images** →
remove the old `voice-project-backend`/`voice-project-whisper` images →
load the new `.tar` files → **Stacks** → `voice-project` → **Update the
stack** with **Re-pull image** enabled.
