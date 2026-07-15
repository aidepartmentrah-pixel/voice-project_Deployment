# Validation Checklist

Run through this after every install and every update, before declaring the
deployment operational (per the RAH Lab Operator Manual's deployment
checklist).

## Containers

- [ ] `docker compose ps` shows all 5 services (`sqlserver`, `db-init`,
      `whisper`, `backend`, `nginx`) — `db-init` shows `Exited (0)`, all
      others show `Up` and `(healthy)` where a healthcheck exists.

## Database

- [ ] `db-init` logs end with `==> Database installation complete.`
      (`docker compose logs db-init`)
- [ ] `scripts/verify_installation.sh` reports all hard-fail checks as
      `PASS` (tables, schema version).

## Backend

- [ ] `https://<server-ip>/` loads the frontend (accept the self-signed
      cert warning).
- [ ] Log in with `admin` / `admin123` succeeds.
- [ ] **Changed the default admin password** — do not leave it as
      `admin123` on anything but a first-boot test.
- [ ] A voice recording round-trip (record → transcribe → fields populate)
      works — confirms `backend` ↔ `whisper` connectivity over the Compose
      network, not `localhost`.
- [ ] Saving a transfusion or delivery form succeeds and shows up in
      History — confirms `backend` ↔ `sqlserver` connectivity.
- [ ] Uploading an Excel file to the analytics dashboard succeeds.

## Persistence

- [ ] `docker compose restart backend` — uploaded Excel files and audio
      recordings are still present afterward (volume check).
- [ ] `docker compose restart sqlserver` — previously saved records are
      still present afterward (volume check).

## Security basics

- [ ] `.env` is not world-readable (`chmod 600 .env` if needed) and was not
      copied via an unapproved transfer method.
- [ ] `JWT_SECRET` is a real random value, not left as any documentation
      placeholder.
- [ ] Port 1433 (SQL Server) is only reachable from where it needs to be —
      don't expose it more broadly than required for GUI DB tools.
