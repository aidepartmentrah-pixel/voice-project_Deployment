# Troubleshooting

## "port is already allocated" — installation fails while starting the stack

Happens on a shared offline host that already runs another project's own
Docker containers (RAH Lab's standard pattern is multiple projects per VM —
see `RAH Lab Operator Manual` §2.5). By default this release asks for host
ports `1433` (SQL Server, external tools only), `80`, and `443` (nginx —
the actual app entry point). If another project already has one of these
(most commonly `1433`, since every SQL-Server-backed project defaults to
it), `docker compose up` fails immediately with this error.

**Fix — change the conflicting port in `compose/.env`, not the other
project.** For `1433` specifically:

```bash
nano compose/.env   # change DB_PORT=1433 to a free port, e.g. DB_PORT=5433
```

This only affects the host-side port used by external DB tools (DBeaver,
SSMS) — the app itself always talks to SQL Server over Docker's internal
network on the unchanged container-internal port `1433`, so this is always
safe to change.

Before picking a replacement port, confirm it's actually free on this host
(don't guess):

```bash
for port in 5433 80 443; do
  (echo > /dev/tcp/127.0.0.1/$port) 2>/dev/null && echo "$port: IN USE" || echo "$port: free"
done
```

If `80` or `443` themselves collide (less common — most other projects on a
shared host tend to use non-standard ports for their own frontends), those
require editing `compose/docker-compose.yml`'s `nginx` service `ports:`
section directly, since they're not parameterized via `.env` the way
`DB_PORT` is.

**Record whatever port you end up using** in this host's infrastructure
snapshot/port registry, if one is kept (see the RAH Lab Operator Manual's
Release Register guidance) — so the next project deployed on this VM
doesn't hit the same collision blind.

## `verify_installation.sh` / `backup_database.sh` / `restore_database.sh` fail with "Invalid filename"

This looks identical to a path bug that was fixed earlier, but if you're
still seeing it, the more likely cause now is a **permission** problem, not
a path problem: the `sqlserver` container runs as a fixed non-root UID, and
`database/` + `scripts/` (bind-mounted read-only into that container so
these scripts can exec `sqlcmd` against them) may have been extracted/copied
with a restrictive mode — e.g. `700`, owner-only — that UID can't read at
all. `install_offline.sh` and `start_stack.sh` both run
`chmod -R o+rX database scripts` automatically to prevent this, but if you
copied the release some other way (rsync with `--perms`, a tar that
preserved restrictive modes, etc.) after those scripts already ran, re-run:

```bash
chmod -R o+rX database scripts
```

Same root cause class as a permission issue found on a sibling RAH Lab
project (STT-SCHEDULE's pgAdmin container hitting the same non-root-UID
vs. restrictive-host-mount problem) — any time a container runs as a fixed
non-root user and reads from a host bind mount, the mount's permissions
need to allow that UID access, regardless of which UID did the extracting.

## `sqlserver` container is `(unhealthy)` / "dependency failed to start: container ... is unhealthy"

`install_offline.sh`/`start_stack.sh` check `DB_SA_PASSWORD`/`DB_PASSWORD`
for basic strength before starting anything, specifically to catch this
ahead of time — so if you're seeing this, either that check was bypassed
(compose was started some other way) or `.env` was edited *after* a failed
first attempt. Confirm:

```bash
docker inspect --format='{{json .State.Health}}' compose-sqlserver-1
```

`"Login failed for user 'sa'"` in the output confirms a password problem.
SQL Server only applies `MSSQL_SA_PASSWORD` the very first time it sees a
**truly empty** data volume — if `sqlserver` already failed once (even with
a bad password), Docker already created that volume, and simply fixing
`.env` and retrying will hit the exact same failure, because SQL Server now
thinks it's already initialized and skips setting the password again. You
must remove the volume too:

```bash
docker compose down -v
```

Then confirm `DB_SA_PASSWORD` and `DB_PASSWORD` in `compose/.env` are both
real, non-empty values meeting SQL Server's complexity policy (8+ chars, at
least 3 of: uppercase, lowercase, digit, symbol) — not left blank from the
template — before retrying `./scripts/install_offline.sh`.

## `whisper` container crash-loops with `httpx.ConnectError` / DNS resolution error

```bash
docker compose logs whisper
```

As of this release the Whisper model is baked directly into `whisper.tar`
at build time (no separate `assets/whisper-model-medium.zip` extraction
step exists anymore — see `RELEASE_NOTES.md`'s 1.2.0 section), so this
specific failure mode should no longer be possible from a normal install.
If you still see `Temporary failure in name resolution` or anything trying
to reach `huggingface.co` in the logs, the loaded `whisper` image itself is
suspect — confirm `docker-images/whisper.tar` actually matches this
release (re-run `scripts/load_images.sh`, or verify
`checksums/release_hashes.txt`), and confirm `WHISPER_MODEL_PATH` in
`compose/docker-compose.yml`'s `whisper` service is still
`/models/whisper-medium` and hasn't been hand-edited.

Confirm it worked — `docker compose logs whisper` should show
`model_source=/models/whisper-medium` and no network activity at all. This
container is designed to never need internet.

## `db-init` container exits with an error / `backend` never starts

```bash
docker compose logs db-init
```

Common causes:
- **Wrong `DB_SA_PASSWORD`** in `.env` — must match what `sqlserver` was
  first created with (SQL Server sets the `sa` password from
  `MSSQL_SA_PASSWORD` only on the container's very first start; changing
  `.env` afterward does not change it — see "I need to change the sa
  password" below).
- **`sqlserver` not healthy yet** — `db-init` waits up to ~60s; if the host
  is slow, increase the retry loop in `scripts/install_database.sh`.
- **Password doesn't meet SQL Server's complexity policy** — needs 8+
  characters and at least 3 of: uppercase, lowercase, digit, symbol.

## Browser shows a certificate warning

Expected for a self-signed certificate on an internal hospital network.
Confirm the IP in the address bar is correct, then accept/proceed. To
generate a proper cert for this host's actual IP:

```bash
./nginx/generate_self_signed_cert.sh <this-server's-IP>
docker compose restart nginx
```

## Microphone/voice recording doesn't work in the browser

`getUserMedia()` (the mic API) requires a secure context — confirm you're
accessing the app via `https://`, not `http://` (nginx redirects `:80` to
`:443` automatically, but a bookmarked `http://` link with a typo won't).

## "Python Whisper service not running" error on upload

```bash
docker compose ps whisper
docker compose logs whisper
```

Check the container is `Up`; check logs for a crash (e.g. out-of-memory —
see "Whisper container keeps restarting" below).

## Whisper container keeps restarting / OOM

The Whisper model needs real RAM: "medium" needs ~1.5GB+ resident, "small"
needs ~0.5GB. If the host is tight on memory (SQL Server + backend + whisper
all running concurrently), drop to `WHISPER_MODEL=small` in `.env`, then:

```bash
docker compose up -d --build whisper
```

## I need to change the `sa` password after first install

SQL Server only reads `MSSQL_SA_PASSWORD` on the container's first-ever
start (it initializes the master database then). To change it afterward:

```bash
docker compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "<old password>" -C \
  -Q "ALTER LOGIN sa WITH PASSWORD = '<new password>'"
```

Then update `DB_SA_PASSWORD` in `.env` to match (for future backup/restore/
migration commands — the running `backend`/`db-init` don't need to be
restarted since they don't use the `sa` login).

## A container shows `(unhealthy)`

```bash
docker inspect --format='{{json .State.Health}}' <container-name> | python3 -m json.tool
```

Shows the last few healthcheck attempts and their output — usually enough
to diagnose without digging further.

## RAG chatbot / Ollama

**`ollama` or `rag-chatbot` container shows `(unhealthy)` / not running at
all**: first confirm the profile was actually enabled —
`docker compose ps` won't show either container at all if it wasn't (see
`INSTALL_OFFLINE.md`'s "Enabling the optional RAG chatbot"). If it was
enabled, check `docker compose logs ollama` and
`docker compose logs rag-chatbot`.

**Chat feature in the UI returns "RAG chatbot service not running"**: this
is the correct, expected message if the profile was never enabled at this
site — not a bug. If you expected it to be running, confirm with
`docker compose ps` that both `ollama` and `rag-chatbot` show `Up`.

**Chatbot answers seem stale / don't reflect recent eDelphyn changes**:
known limitation as of this release — the chatbot's search index only
refreshes once, at container startup. Force a refresh with
`docker compose restart rag-chatbot` (check
`docker compose logs rag-chatbot` afterward to confirm the refresh
succeeded rather than failing silently against an unreachable eDelphyn).

**Chatbot always answers "not verified" / has nothing to say about real
data**: the startup data refresh likely failed. Check
`docker compose logs rag-chatbot` for a `WARNING -- data refresh failed`
line — this almost always means `EDELPHYN_DB_*` in `compose/.env` is
wrong, unreachable, or eDelphyn requires Windows-Auth (see
`INSTALL_OFFLINE.md`'s Prerequisites section — this is a hard blocker,
not something to keep debugging locally).

**A question takes a very long time (many seconds) to answer**: expected
for open-ended questions that fall through to the local LLM
(`phi3:mini`) rather than being answered directly from the data — this
deployment runs CPU-only, no GPU. Questions matching an exact count/
breakdown/trend pattern answer near-instantly; anything more open-ended
does not.

## Nothing works and I want to start over (fresh database)

**Destroys all data.** Only do this on a fresh/test install, never on a
server holding real records:

```bash
docker compose down -v   # -v removes the sqlserver_data volume too
docker compose up -d
```
