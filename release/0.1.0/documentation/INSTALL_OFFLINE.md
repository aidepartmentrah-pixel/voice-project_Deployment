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

## The easy way — after Steps 1 and 2, one command

```bash
cd release
./scripts/install_offline.sh
```

This runs every automated step below in order (Steps 3-6).
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

## Step 3 — Extract the Whisper model asset

```bash
unzip -o assets/whisper-model-medium.zip -d assets
```

This is a pre-downloaded copy of the actual Whisper "medium" model files
(`model.bin`, `tokenizer.json`, etc.) — the Whisper container loads this
directly from disk and **never** contacts huggingface.co. Skipping this
step is the single most common install failure: the `whisper` container
will crash-loop with a DNS resolution error if this asset isn't in place
before the stack starts.

(`install_offline.sh` does Steps 3-6 automatically — if you're running the
one-command version from above, you can skip manually running this and the
next three steps.)

## Step 4 — Load the Docker images

```bash
./scripts/load_images.sh
```

Expected output ends with:
```
==> All images loaded.
```

This reads `docker-images/*.tar` (produced on the Build Workstation by
`docker save`) and loads them into the local Docker Engine with
`docker load` — no internet or Docker Hub access required.

## Step 5 — Start the stack

```bash
./scripts/start_stack.sh
```

This first validates `DB_PASSWORD`/`DB_SA_PASSWORD` from `.env` (see Step 1)
and refuses to continue if either is missing or weak. Then it runs
`docker compose up -d`, which will:
1. Start `sqlserver` and wait for its healthcheck.
2. Run `db-init` once (installs the database package — see
   `docs/DATABASE_INSTALL_GUIDE.md`), and exit 0 on success.
3. Start `whisper` (loading the model from Step 3) and `backend`.
4. Start `nginx`, which is the only port exposed to the network (`80`/`443`).

## Step 6 — Verify

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
on its health route through nginx.

## Step 7 — First login

Open `https://<offline-server-IP>/` in a browser — the same IP you used to
generate the certificate in Step 2. The browser will warn about the
self-signed certificate; this is expected for an internal hospital network —
accept/proceed once you've confirmed you're on the correct IP.

Log in with `admin` / `admin123` (seeded automatically by the backend on
first startup) and **change this password immediately** via the Users page.

## If something fails

See `TROUBLESHOOTING.md`.
