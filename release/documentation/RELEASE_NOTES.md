# Release Notes

## 1.0.0 — Initial Dockerized release

First Dockerized release of `voice-project` (Blood Bank voice-transcription
system), converting the existing Windows/manual-setup deployment into a
repeatable offline Debian Docker deployment. No business behavior was
changed — this release is deployment infrastructure only.

### What's included

- SQL Server Database Package (`database/sqlserver/`) — install, migrations
  scaffold, validation, rollback, and backup/restore scripts for
  `BloodBankDB`. See `docs/DATABASE_STRUCTURE_REPORT.md` for exactly which
  tables are confirmed-from-code vs. inferred from query usage.
- Docker images: `node-backend` (serves API + static frontend),
  `python-service` (Whisper transcription), `db-init` (one-shot database
  installer), reverse-proxied by `nginx` (TLS termination).
- `docker-compose.yml` wiring all five services with named volumes for SQL
  Server data and uploaded files (audio + Excel).

### Fixes made to support Dockerization (behavior-preserving)

- `node-backend/db.js`: removed hardcoded fallback server/database/user
  values; now fails loudly if required env vars are missing instead of
  silently connecting to a stale default.
- `node-backend/server.js`: replaced two literal `http://localhost:5001/transcribe`
  call sites with `WHISPER_SERVICE_URL` (env-configurable, defaults to the
  Compose service name).
- `python-service/whisper_service.py`: `app.run()` now binds `0.0.0.0`
  instead of Flask's default `127.0.0.1` (otherwise unreachable from other
  containers); model size now configurable via `WHISPER_MODEL` env var.
- Added `python-service/requirements.txt` (did not exist before).
- Added TLS via an nginx reverse-proxy container — the app previously had
  no working in-app HTTPS despite older documentation referencing a
  `:3443`/certs setup; verified by inspecting the current source before
  building this.

### Fixes made after first offline validation attempt

The first build of this release passed local testing on the Build
Workstation but failed on the real offline validation host. Root-caused and
fixed all three:

- **Whisper container crash-looped offline** (`httpx.ConnectError` / DNS
  resolution failure trying to reach huggingface.co). Root cause: the model
  was baked into the image at build time based on whatever `WHISPER_MODEL`
  the build happened to use, but the runtime `WHISPER_MODEL` env var could
  specify a different size — a mismatch triggered a live re-download attempt
  that can never succeed offline. Fixed by removing the build-time bake
  entirely; `whisper_service.py` now loads the model from a mounted local
  directory (`WHISPER_MODEL_PATH`) populated by `scripts/export_whisper_model.sh`
  and shipped as `assets/whisper-model-medium.zip` — the same pattern
  STT-SCHEDULE uses for its own model asset. `HF_HUB_OFFLINE=1` is set as a
  defense-in-depth safety net.
- **`verify_installation.sh`/`backup_database.sh`/`restore_database.sh`
  validated nothing** ("Invalid filename" on every check, though it still
  correctly reported overall failure rather than a false pass). Root cause:
  these scripts exec into the `sqlserver` container (the untouched official
  Microsoft image), which never had any of our SQL files mounted or copied
  into it, and the release package's flattened `database/` folder also
  didn't match the relative-path assumptions baked into `verify_database.sql`'s
  `:r` includes. Fixed by reorganizing `release/database/` + `release/scripts/`
  to mirror the repo-root sibling layout those includes assume, and mounting
  both into the `sqlserver` container read-only.
- **Compose project name collision risk**: this release's compose file lives
  in a directory literally named `compose/` — a convention apparently shared
  by other RAH Lab release packages — so Docker Compose's default
  directory-derived project naming could collide with an unrelated project
  on the same host (confirmed happening during testing on a shared machine).
  Fixed by pinning an explicit `name: voice-project` in the compose file.
- **SQL Server startup failure class hardened against** (not something we
  hit ourselves, but a documented failure from a sibling project's offline
  validation): an empty or weak `DB_SA_PASSWORD`/`DB_PASSWORD` makes the
  `sqlserver` container fail its healthcheck, cascading into a confusing
  "dependency failed to start" error with no obvious link back to the real
  cause. Added `scripts/_preflight_checks.sh`, run automatically by both
  `install_offline.sh` and `start_stack.sh`, which validates both passwords
  against SQL Server's actual complexity policy *before* `docker compose up`
  ever runs, failing fast with a clear message instead.

### Fix made after second offline re-validation attempt

Whisper and the database-verification bind mount both re-validated as
working on the real offline host. One new bug surfaced, same root cause
class as a permission issue found on a sibling project (STT-SCHEDULE's
pgAdmin container), just recurring in a spot that hadn't been generalized
to it yet:

- **`verify_installation.sh`/`backup_database.sh`/`restore_database.sh`
  failed with "Invalid filename" again** — this time not a path bug, a
  genuine permission denial wearing the same error text. The `sqlserver`
  container runs as a fixed non-root UID; the host `database/` and
  `scripts/` directories (bind-mounted read-only for these scripts) can end
  up mode `700` (owner-only) depending on how the release was extracted or
  copied onto the offline host, which that UID has zero permission to even
  open. Confirmed by manually running `chmod -R o+rX database scripts`,
  which immediately fixed it — all checks then ran for real. Fixed
  permanently by having `install_offline.sh` and `start_stack.sh` both run
  that same `chmod -R o+rX` automatically before starting the stack, so it
  no longer depends on whatever mode the release happened to arrive in.

### Fix found during local pre-release testing (before this offline pass)

- **Login failed with "Cannot connect to server. Is it running?" whenever
  the app was accessed via anything other than literally `localhost`** (its
  real IP, a LAN hostname, etc. — i.e. every real-world access pattern once
  behind nginx). Root cause: `frontend/index.html` hardcoded
  `const API = 'http://localhost:3000'` and three other call sites
  hardcoded the same literal URL. `localhost` always resolves to whatever
  machine the *browser* is running on, not the server — and the backend
  isn't even exposed on host port 3000 anymore now that nginx is the only
  published port. This is a pre-existing bug in the original application
  (not something Dockerization introduced), but it went unnoticed before
  because the dev backend genuinely did listen on `localhost:3000` when run
  directly, outside Docker. Fixed by changing `API` to an empty string and
  making the other three call sites relative (`/mode-check`, `/upload`,
  `/upload/batch`) — all requests now go to whatever origin actually served
  the page, which nginx correctly proxies to the backend regardless of
  hostname/IP. Verified by loading the actual exported `backend.tar` (not
  just the pre-export image) and confirming the fix is present in the
  baked-in `frontend/index.html`, plus a live login test via the LAN IP.

  **Also fixed while investigating this**: `scripts/export_images.sh` was
  tagging and saving images from `voice-project_deployment-*` — the
  directory-derived default project name — which went stale the moment
  `docker-compose.yml` was given an explicit `name: voice-project-dev`
  pin (see the project-name-collision fix above). This meant a rebuilt
  image could be silently skipped in favor of a stale same-named image left
  over from before that pin existed, exactly what happened with this very
  fix on the first export attempt. Corrected to tag from
  `voice-project-dev-*` instead, and confirmed by checking the exported
  image's ID matches the actual latest build before trusting the tar.

### Fix found during real offline installation on OR-LAB (150.50.10.30)

- **`docker compose up` failed with "port is already allocated"** —
  `DB_PORT`'s default (`1433`) collided with another project's SQL Server
  container already running on this shared host (HCopilot). Not a bug —
  this is exactly what `DB_PORT` being configurable was for — but the
  template didn't call out that a shared multi-project host is likely to
  hit this on the very first install. Resolved by setting `DB_PORT=5433` in
  `compose/.env` (host-side only; app-to-app traffic is unaffected since it
  always uses the container-internal port `1433` regardless of this value).
  `.env.offline.template` and `TROUBLESHOOTING.md` now document the check-
  before-you-install command and this exact fix.

### Fixes found reproducing "Database not connected" on the Build Workstation

The same "Database not connected" symptom reported on OR-LAB was reproduced
locally and root-caused to two separate, compounding bugs:

- **`node-backend/server.js`'s `initDB()` tried to connect to SQL Server
  exactly once at startup and never retried.** If the backend container
  starts (or restarts) before SQL Server is ready to accept connections —
  a laptop sleep/wake cycle, a Docker Desktop restart, or any container
  restart that bypasses Compose's `depends_on` ordering (a raw `docker
  restart`, or Docker Desktop's UI restart button) — this left `dbReady`
  stuck `false` for the rest of that process's life, with no automatic
  recovery even after SQL Server became healthy. Fixed by retrying the
  connection indefinitely every 10 seconds until it succeeds, instead of
  giving up permanently after one attempt. Verified by deliberately
  restarting the backend container while SQL Server was stopped, then
  starting SQL Server back up — the backend reconnected on its own within
  10 seconds, no manual intervention.
- **`nginx.conf` resolved the `backend` hostname once at nginx startup and
  cached that IP for the life of the worker process.** Any time the
  `backend` container is recreated (a normal image update, a crash
  restart, anything giving it a new container = new internal Docker
  network IP), nginx kept sending requests to the stale IP and returned
  `502 Bad Gateway` until nginx itself was also restarted — which nothing
  in the normal update flow (`docker compose up -d`) does automatically.
  Fixed by adding `resolver 127.0.0.11` (Docker's embedded DNS) and
  switching both `proxy_pass` directives to use a variable, which forces
  nginx to re-resolve the hostname per-request instead of once at startup.
  Verified by force-recreating the backend container and confirming login
  worked immediately, without touching nginx.

These two together fully explain the "Database not connected" behavior
seen on both the Build Workstation and OR-LAB: whichever container started
in the wrong order relative to its dependency, the app had no way to
recover without a manual restart. Both offline and online deployments now
self-heal from this class of timing issue.

### Known limitations / follow-ups

- `TransfusionRequests`, `BloodDeliveries`, and `VoiceTranscriptions` schema
  definitions in `database/sqlserver/install/002_create_schema.sql` are
  reconstructed from query usage in `server.js`, not confirmed against a
  live schema dump — see `docs/DATABASE_STRUCTURE_REPORT.md` for exactly
  what's unverified. Re-validate against the live source database before
  treating this package as authoritative.
- `WHISPER_MODEL` default (`medium`) was sized for the Build Workstation's
  specs — re-confirm available RAM/cores on the actual offline production
  host before deploying.
