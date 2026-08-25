# Install Offline — voice-project (Blood Bank)

For an IT employee installing this on the offline Debian Docker host for
the first time. Every command below is exact — copy/paste it as written.

## What you need before starting

- This release folder, copied onto the offline server (via the hospital's
  approved DVD/USB transfer procedure).
- Docker Engine already installed and running on the offline server (per
  the Offline Debian Server Kit — this release does not install Docker
  itself).
- A filled-in `.env` file and a TLS certificate — see Steps 1 and 2 below.
  Both are manual and must be done before starting the stack.

## Prerequisites — verify with hospital IT before starting (only if enabling the optional RAG chatbot)

The optional RAG chatbot ("Enabling the optional RAG chatbot" below)
depends on this hospital's eDelphyn (Laboratory Information System) SQL
Server. **Skip this whole section if this site will not enable that
profile** — nothing else in this release needs it.

- [ ] **SQL Server login (username+password) authentication, not
  Windows-Auth-only.** This application's Settings page has a "Windows
  Auth" toggle that is hardcoded disabled (the `msnodesqlv8` driver isn't
  installed) — it can only connect to eDelphyn using SQL Server login
  auth. Ask hospital IT to confirm the eDelphyn SQL Server instance
  accepts SQL Server logins (Mixed Mode authentication), not
  Windows-integrated-only. If it's Windows-Auth-only, the eDelphyn
  integration (and therefore the RAG chatbot) cannot work at this site
  without further engineering work — do not attempt this profile.
- [ ] **Same-LAN network reachability** from this offline server to the
  real eDelphyn SQL Server (internal hospital LAN traffic — this is
  compatible with the air-gapped deployment model; it is not internet
  access). Confirm the port (`EDELPHYN_DB_PORT`, default 1433) is open
  between the two hosts.

## The easy way — after Steps 1 and 2, one command

```bash
cd release
./scripts/install_offline.sh
```

This runs every automated step below in order (Steps 3-5).
`install_offline.sh` does not create `.env` or the certificate for you —
those are Steps 1 and 2, manual, do them first. The full step-by-step
breakdown follows for anyone who wants to understand (or troubleshoot)
what's happening.

## Step 1 — Create and fill in `.env`

```bash
cd release
cp compose/.env.offline.template compose/.env
nano compose/.env   # fill in DB_PASSWORD, DB_SA_PASSWORD, JWT_SECRET
```

> **⚠️ Always start from `compose/.env.offline.template`.** Never copy a
> developer's already-filled `.env` (from a dev machine, a git stash, a
> Slack message, etc.) as a shortcut. A developer's `.env` may contain
> values that only make sense on their machine — e.g. `EDELPHYN_DB_NAME`
> pointed at a synthetic test database with a fake password — which would
> silently point this hospital's installation at the wrong (or a
> nonexistent) database instead of cleanly failing. `.env.offline.template`
> ships every `EDELPHYN_DB_*` field blank on purpose; fill them in fresh
> for this specific hospital site.

**Do not leave these blank or use weak values** — `install_offline.sh` will
refuse to start if `DB_PASSWORD`/`DB_SA_PASSWORD` are empty or don't meet
SQL Server's complexity policy (8+ characters, at least 3 of: uppercase,
lowercase, digit, symbol), so this is caught early with a clear message
rather than failing confusingly later.

## Step 2 — Generate a TLS certificate for this server

```bash
cd release/compose
./nginx/generate_self_signed_cert.sh <this-server's-actual-IP>
cd ..
```

Replace `<this-server's-actual-IP>` with the real IP address hospital staff
will use to reach this machine (add more, space-separated, if it has
several — e.g. a LAN IP and `localhost`). This writes `cert.pem`/`key.pem`
into `compose/nginx/certs/`. A cert generated for the wrong IP will still
let the page load but will show a certificate name-mismatch warning in
addition to the usual self-signed warning — regenerate it here if that
happens, don't just click through extra warnings. Skipping this step
entirely makes `nginx` crash-loop (it has nothing to load for HTTPS).

(`install_offline.sh` does Steps 3-5 automatically — if you're running the
one-command version from above, you can skip manually running this and the
next two steps.)

## Step 3 — Load the Docker images

```bash
./scripts/load_images.sh
```

Expected output ends with:
```
==> All images loaded.
```

This reads `docker-images/*.tar` (produced on the Build Workstation by
`docker save`) and loads them into the local Docker Engine with
`docker load` — no internet or Docker Hub access required. The Whisper
speech-to-text model is baked directly into `whisper.tar` as of this
release (no separate extraction step, unlike earlier releases — see
`RELEASE_NOTES.md`).

## Step 4 — Start the stack

```bash
./scripts/start_stack.sh
```

This first validates `DB_PASSWORD`/`DB_SA_PASSWORD` from `.env` (see Step 1)
and refuses to continue if either is missing or weak. Then it runs
`docker compose up -d`, which will:
1. Start `sqlserver` and wait for its healthcheck.
2. Run `db-init` once (installs the database package — see
   `docs/DATABASE_INSTALL_GUIDE.md`), and exit 0 on success.
3. Start `whisper` and `backend`.
4. Start `nginx`, which is the only port exposed to the network (`80`/`443`).

This does **not** start the optional RAG chatbot (`ollama`/`rag-chatbot`) —
see "Enabling the optional RAG chatbot" below.

## Step 5 — Verify

```bash
./scripts/verify_installation.sh
```

Expected output ends with:
```
==> Installation verified — application is healthy.
```

This checks: all containers are `Up` (and `healthy` where a healthcheck
exists), the database validation checks pass for real (not just headers —
see `RELEASE_NOTES.md` if that phrasing seems odd), and the backend responds
on its health route through nginx. It also checks the optional RAG chatbot
if that profile is running — see below — and skips that check silently if
it isn't.

## Step 6 — First login

Open `https://<offline-server-IP>/` in a browser — the same IP you used to
generate the certificate in Step 2. The browser will warn about the
self-signed certificate; this is expected for an internal hospital network —
accept/proceed once you've confirmed you're on the correct IP.

Log in with `admin` / `admin123` (seeded automatically by the backend on
first startup) and **change this password immediately** via the Users page.

## Enabling the optional RAG chatbot

Off by default. Only enable this if this hospital site has eDelphyn, you've
confirmed the Prerequisites checklist above, and `EDELPHYN_DB_*` is filled
in and working in `compose/.env` (test it via Settings → Database → Test
Connection after first login, before enabling this).

```bash
cd release/compose
docker compose --profile rag-chatbot up -d
```

This starts two additional containers: `ollama` (the local LLM runtime,
with its two required models already baked into the image) and
`rag-chatbot` (the chat web UI/API, proxied through the main app at
`/api/rag-chat`). On first startup, `rag-chatbot` pulls a snapshot of
eDelphyn data and builds its local search index once — this can take a
minute or two and needs `backend`/`EDELPHYN_DB_*` to be reachable at that
moment. **Known limitation:** the index only refreshes at container
startup — data goes stale until the container is restarted
(`docker compose restart rag-chatbot`); there is no automatic periodic
refresh in this release.

`update_offline.sh` detects automatically if this profile was previously
enabled at this site and carries it forward during an update — no extra
flag needed on update, only on the first time you enable it.

## If something fails

See `TROUBLESHOOTING.md`.
