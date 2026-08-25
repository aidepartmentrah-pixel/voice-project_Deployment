# Release Notes

## 1.2.0 hotfix (2026-08-20) — eDelphyn `LOG_ENTRY` type-mismatch crash on `external_units`

**Field-reported bug, confirmed and fixed.** A real hospital site's eDelphyn
schema stores `dbo.DONATION.LOG_ENTRY` as text (`'Y'`/`'N'`) rather than the
numeric (`bit`/`int`, `1`/`0`) convention the query assumed. The `external_units`
Live Dashboard category (`node-backend/edelphynQueries.js`) compared it with
`d.LOG_ENTRY = 1`, which threw a hard SQL Server error on that site —
`Conversion failed when converting the varchar value 'Y' to data type int` —
aborting the whole dashboard load (it stops at the first category failure)
and crash-looping the optional RAG chatbot's startup snapshot (`fetch_snapshot.py`
requires all 6 categories to succeed).

**Fix:** `d.LOG_ENTRY = 1` replaced with a type-agnostic
`CAST(d.LOG_ENTRY AS varchar(10)) IN ('1', 'Y', 'true', 'TRUE')`, which works
correctly regardless of whether the underlying column is numeric or text.
Verified against the synthetic `eDelphyn_test` fixture (numeric/`bit`
convention, unchanged row count before/after: 11/11) and against a simulated
text-convention copy of the same data (also 11/11) — both conventions now
resolve identically.

**Proactively hardened, same bug class, NOT independently confirmed against
real hospital data** — found by pattern-matching every other raw
`LOG_*`/`COD_*` flag-column comparison in `node-backend/edelphynQueries.js`
and `node-backend/edelphynAnalyticsQueries.js` for the same implicit-type-
coercion risk, and applying the identical `CAST(... AS varchar(N))` guard:
- `edelphynQueries.js`: `COD_RETURN` (transfusion `[Returned]`, sent_to_centres
  `[Returned]`), `LOG_CANCELLED` (requests/`ORDERFORM` path).
- `edelphynAnalyticsQueries.js`: `LOG_WRONGMOBILE`/`LOG_WRONGEMAIL`
  (donor-recall `PhoneAvailable`/`EmailAvailable`), `COD_RETURN` (unit
  return-rate).
- All 6 Live Dashboard categories (`external_units`, `donors`, `requests`,
  `transfusion`, `sent_to_centres`, `wasted`) were exercised end-to-end
  through the real `/api/dashboard/category-query` route against the
  synthetic `eDelphyn_test` data after this fix — all return HTTP 200 with
  no regression. The `/api/analytics/return-rate` endpoint (uses the fixed
  `COD_RETURN` pattern) also returns HTTP 200.
- **These 5 additional locations still need verification against real
  hospital eDelphyn data before the eDelphyn integration can be called
  fully verified** — the synthetic fixture only exercises the
  numeric/`bit` convention (matching the fixture's own schema), not any
  site's actual text-convention storage. Test each category via
  `POST /api/dashboard/category-query` at the hospital site per the
  original bug report's own recommendation.

**Deployment note:** this is a minimal-footprint hotfix — only
`docker-images/backend.tar` changed (rebuilt from `node-backend/Dockerfile`,
same `voice-project-backend:1.2.0` tag; `checksums/release_hashes.txt`
updated accordingly). No other image, compose file, or database migration
is affected. To apply: `docker load -i docker-images/backend.tar` then
`docker compose up -d backend` — no full reinstall needed.

## 1.2.0 — Baked Whisper/Ollama models, optional offline RAG chatbot, eDelphyn credential hardening

### What's new

- **Whisper model delivery changed from runtime bind-mount to baked-into-
  image.** `docker-images/whisper.tar` now contains the "medium" model
  files directly (`COPY`'d in at `docker build` time — see
  `python-service/Dockerfile` in the source repo). `install_offline.sh` no
  longer has a "extract `assets/whisper-model-medium.zip`" step, and
  `compose/docker-compose.yml`'s `whisper` service no longer has a
  `volumes:` bind mount for the model. This follows the platform's Runtime
  Self-Containment rule: every application-owned runtime artifact must
  already be inside the image when `docker build` finishes, not supplied
  only via a runtime bind mount. `release/0.1.2/` no longer ships an
  `assets/` directory at all as a result — nothing left needs it.

- **New optional feature: offline RAG chatbot** (`rag-chatbot` + `ollama`
  Docker services, both gated behind Compose's `rag-chatbot` profile — OFF
  by default). Lets staff ask natural-language questions about blood bank
  records, answered by a fully local/offline LLM (`phi3:mini`, via Ollama)
  grounded in a Chroma vector index built from a live eDelphyn snapshot. To
  enable: `docker compose --profile rag-chatbot up -d` (see
  `INSTALL_OFFLINE.md`, "Enabling the optional RAG chatbot"). **Requires
  the hospital's eDelphyn LIS to be reachable and configured**
  (`EDELPHYN_DB_*` in `.env`) — see the new Prerequisites checklist in
  `INSTALL_OFFLINE.md` before attempting this, especially the
  SQL-Server-login-vs-Windows-Auth requirement below.
  - **Known limitation (v1):** the vector index refreshes once, at
    container startup, only. Data goes stale until the `rag-chatbot`
    container is restarted (`docker compose restart rag-chatbot`); there
    is no periodic/scheduled refresh in this release.
  - **Known limitation:** `rag-chatbot`'s own `/api/chat` endpoint has no
    authentication of its own — it is reachable only via `node-backend`'s
    `/api/rag-chat` proxy route, which IS behind login auth, and is never
    published on a host port.
  - **Sizing note:** open-ended questions that fall through to the local
    LLM took roughly 20-25 seconds on the Build Workstation's CPU (no GPU)
    during testing — questions matching an exact count/breakdown/trend
    pattern answer near-instantly instead. Re-confirm actual latency on
    the real target server's hardware; it will differ by machine.
  - The `ollama` image ships as the upstream default (root user) rather
    than this project's usual non-root container convention — a
    deliberate, documented exception (the upstream image has no
    pre-configured non-root user, and changing that was out of scope for
    this release).
  - `node-backend/server.js`'s `/mode-check` endpoint now performs a real,
    short-timeout, cached health check against the `ollama` service
    instead of a hardcoded `ollamaRunning: false` stub.

- **eDelphyn credential handling hardened** (carried from engineering work
  done between 1.1.0 and this release; first shipping in a release here):
  - `node-backend/db.js` fails loudly at startup (clear error, process
    exits) if `DB_SERVER`/`DB_NAME`/`DB_USER`/`DB_PASSWORD` are unset,
    instead of silently connecting with an empty string.
  - The Settings page's "save eDelphyn credentials" action
    (`PUT /api/settings/db`) is **disabled by default** in this deployment
    (`ALLOW_RUNTIME_DB_SETTINGS` unset/false — see
    `compose/.env.offline.template`). This is deliberate, not a bug:
    letting the UI silently persist credentials to a second file
    (`node-backend/config/db-settings.json`) would create undocumented
    configuration drift from the `.env`-is-the-only-source-of-truth model
    this deployment is built on. eDelphyn credentials are filled into
    `.env` by the installing engineer before running `install_offline.sh`,
    the same way `DB_PASSWORD`/`DB_SA_PASSWORD` already work. The
    read-only "Test Connection" button remains available post-install
    regardless of this setting, for validating already-configured values.

### Pre-installation prerequisite (new)

- **eDelphyn Windows-Auth limitation**: this application's Settings page
  "Windows Auth" toggle is hardcoded disabled (the `msnodesqlv8` driver
  isn't installed) — it can only connect to eDelphyn using SQL Server
  login (username+password) authentication. Confirm with hospital IT
  *before* deployment that the site's eDelphyn SQL Server accepts SQL
  Server logins, not Windows-Auth-only — otherwise the eDelphyn
  integration (and the optional RAG chatbot) will not work at that site.
  Only relevant if enabling the RAG chatbot profile.

### Operational warning (new)

- **Always start `.env` from `compose/.env.offline.template`, never from a
  developer's already-filled `.env`.** A developer's file may have
  site-specific-looking values (e.g. `EDELPHYN_DB_NAME=eDelphyn_test`)
  that are only valid on their machine, which would silently misconfigure
  a real install instead of cleanly failing. See `INSTALL_OFFLINE.md`.

### Fixes bundled in this release

- `db-init/Dockerfile`: fixed a real build failure on the Build
  Workstation's network (`deb.debian.org` returning 403 over plain HTTP)
  with a two-stage https-rewrite + CA-trust-store bootstrap
  (`debian:12-slim` ships no trust store at all, so `ca-certificates`
  itself has to be fetched with peer verification temporarily disabled
  before anything else can be verified). Needed for any real `--no-cache`
  rebuild to succeed; this was previously worked around by silently
  reusing a stale image.
- `frontend/index.html`: a Google Fonts CDN `<link>` and a
  `chartjs-plugin-datalabels@2.2.0` CDN `<script>`, both reintroduced by
  upstream merge commits, were caught and fixed — fonts back to the
  existing self-hosted `frontend/fonts/fonts.css`, and
  chartjs-plugin-datalabels self-hosted into
  `frontend/vendor/chartjs-plugin-datalabels.min.js` alongside the
  existing self-hosted `chart.umd.min.js`. Keeps the frontend fully
  functional with no internet access, matching this deployment's offline
  requirement.

### New dependencies

Two new custom images: `voice-project-ollama` and
`voice-project-rag-chatbot`, baked into `docker-images/ollama.tar` and
`docker-images/rag-chatbot.tar` respectively. Both optional
(profile-gated — see above). `IMAGE_VERSION` now applies uniformly to five
custom images (`db-init`/`whisper`/`backend`/`ollama`/`rag-chatbot`), still
one shared variable, defaulting to `1.2.0` in this release.

### Testing scope for this release

Verified in the Online Engineering Environment (a Windows Docker Desktop
sandbox — not the real air-gapped Offline Debian Validation Environment):
all five default services start and pass genuine validation; the optional
`rag-chatbot` profile starts, its data-refresh pipeline runs successfully
against a synthetic eDelphyn test dataset, and both baked Ollama models
(`nomic-embed-text`, `phi3:mini`) were confirmed producing real output
directly from the baked-in image (not a fallback download). **Not yet
verified**, and required before this release is considered field-ready:
true air-gapped network conditions, Debian/Linux-native container
behavior, connectivity to a real hospital eDelphyn server, restart/reboot
survival on the actual target OS, and real-world `phi3:mini` CPU/RAM
sizing on the actual hospital server hardware. See the Offline Debian
Validation Environment process before deploying this release to a real
hospital site.

## 1.1.0 — Real-time chat, monthly reports, handover notes, security hardening

Merged from upstream (`zeinabelsamra/voice-project`, commit `dc9427a0`).
Only the `backend` image changes in this release — `whisper`, `db-init`,
`sqlserver`, and `nginx` images are identical to 1.0.0 (retagged, not
rebuilt). This is the first real test of the offline update procedure: this
folder is meant to be installed via `scripts/update_offline.sh` against a
host that already has 1.0.0 (`release/0.1.0/`) running, not as a fresh
install.

### What's new

- **Real-time inter-department chat** (Socket.IO): online/offline presence
  per department, typing indicators, file attachments, read receipts, and an
  "urgent" flag. Backed by a new `ChatMessages` table and a `department`
  column on `HospitalUsers`, both created automatically by `initDB()` on
  backend startup — no new SQL package files needed, so
  `database/sqlserver/` is unchanged from 1.0.0.
- **Monthly PDF reports, patient history lookup, and handover notes with PDF
  export** — new endpoints and PDF generation added to
  `node-backend/exportForm.js` and `server.js`.
- **Security hardening**:
  - `helmet` security headers.
  - `express-rate-limit` on `/auth/login` (10 attempts / 15 min / IP).
  - `cors` now restricted (`origin: false`, same-host only) instead of
    wide-open.
  - `JWT_SECRET` now **fails the server at startup** if unset, instead of
    silently falling back to a hardcoded default secret. `compose/.env.example`
    and `compose/.env.offline.template` already require this value — no
    template change needed, but confirm the deployed `.env` actually has it
    set before installing this release, or the backend container will
    exit immediately.

### New dependencies

`node-backend/package.json` gained `socket.io`, `helmet`, and
`express-rate-limit`; baked into `voice-project-backend:1.1.0` at build
time — no action needed on the offline host beyond loading the new image.

### Deployment-fork fix bundled in this release: nginx WebSocket proxying

The chat feature above requires a WebSocket connection (the frontend's
Socket.IO client is hardcoded to `transports: ['websocket']`, no
long-polling fallback). `compose/nginx/nginx.conf`'s reverse-proxy config
predates chat and never set the `Upgrade`/`Connection` headers nginx needs
to relay a WebSocket upgrade — without them nginx silently downgrades the
handshake to a plain HTTP request, the upgrade never happens, and chat
fails to connect with no error surfaced anywhere (not even in the backend
logs, since the connection never reaches Socket.IO). Found by actually
testing chat after this release's first local install. Fixed by adding the
standard `map $http_upgrade $connection_upgrade` block and the
corresponding `proxy_set_header Upgrade`/`Connection` lines to the `location
/` block. The `nginx` Docker image itself is unchanged (still
`nginx:1.27-alpine`) — this is a config-file fix only, so no new image tar
was needed.

### Merge notes (local deployment fork only)

This fork's Docker/deployment-specific changes (relative frontend API paths,
`WHISPER_SERVICE_URL` env var, indefinite DB reconnect retry — see the 1.0.0
notes below) were carried forward through the merge with no conflicts in
behavior; only textual merge conflicts in `server.js` around the top-of-file
setup, resolved by keeping both sides' additions.

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
