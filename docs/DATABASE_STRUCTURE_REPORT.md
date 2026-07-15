# Database Structure Report — BloodBankDB (voice-project)

This is the database inventory for the RAH Lab SQL Server Database Package.
Confidence levels matter here more than usual: this database has **no
migration system, no ORM, and no schema-as-code** — until this package
exists, its schema lives only inside whatever live SQL Server instance backs
the app (currently HCAT, `170.70.32.34`). Everything below was reconstructed
by reading `node-backend/db.js` and every raw SQL statement in
`node-backend/server.js`.

## Confidence key

- **CONFIRMED** — table is created verbatim by application code
  (`server.js`'s `initDB()`), so this is not a guess.
- **INFERRED** — table is never created in code; column list/types were
  reconstructed from every `INSERT`/`UPDATE`/`SELECT` that touches it.
  Verify against the live HCAT schema before treating this package as final
  (see the Prerequisite section of the deployment plan).

## 1. Database Structure

| Table | Confidence | Purpose |
|---|---|---|
| `HospitalUsers` | CONFIRMED | Auth: usernames, bcrypt password hashes, role (`admin`/`staff`), active flag. |
| `TransfusionRequests` | INFERRED | One row per transfusion request form submission (voice-parsed or manual). |
| `BloodDeliveries` | INFERRED | One row per blood delivery form submission, including nurse-unit receipt fields added later. |
| `ExternalDeliveries` | CONFIRMED | Deliveries to other centres/hospitals; component details plus a `components_json` overflow column. |
| `VoiceTranscriptions` | INFERRED, lowest confidence | Write-only audit log of every voice-extracted field per upload — never read back by the app itself. |
| `SchemaVersion` | NEW (this package) | Did not exist before; tracks which schema version is installed. |

No foreign keys exist between these tables today — matches are done at the
application layer by `file_number` string equality (see `/dashboard/wastage`,
`/response-times` in `server.js`), not by SQL foreign key constraints. This
package does not introduce FKs, per "do not redesign the database."

## 2. Lookup Data

**None.** Values like `blood_group`, `rh_factor`, `fpc_type`/`ffp_type`/
`plt_type` are free-text `NVARCHAR` columns populated directly from
voice-parsed input (`node-backend/voiceParser.js`) — there is no normalized
`BloodGroups` or `RhFactors` table anywhere in the codebase. See
`install/008_seed_lookup_data.sql`.

## 3. Configuration Data

**None stored in the database.** All configuration (`DB_SERVER`, `DB_PORT`,
`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`, `WHISPER_SERVICE_URL`) is
environment-variable driven, read via `dotenv` in `db.js`/`server.js`. See
`install/009_seed_configuration.sql`.

## 4. Users / Roles / Permissions

- `HospitalUsers.role` is constrained to `'admin'` or `'staff'` by
  application logic (`server.js`'s `validRole` check) — codified as
  `CK_HospitalUsers_role` in `install/004_create_constraints.sql`.
- Authorization is enforced in the Express middleware
  (`requireAuth`/`requireAdmin`), not by SQL Server logins/roles — the app
  connects with a single `DB_USER` service account for all queries.
- A default admin (`admin` / `admin123`) is seeded automatically by
  `server.js`'s own `initDB()` the first time `HospitalUsers` is empty — this
  package deliberately does not duplicate that in SQL (see
  `install/010_seed_users_roles.sql`).

## 5. Business Data

`TransfusionRequests`, `BloodDeliveries`, and `ExternalDeliveries` hold the
actual clinical/operational records (patient name, blood group, units,
physicians, timestamps). This is real hospital data — per RAH Lab policy, it
must never be copied into development/online environments; only the
structure (this report + `install/`) is portable, not production rows.

## 6. Indexes

Added in `install/003_create_indexes.sql`, based on the query patterns
actually used (not speculative): `file_number` lookups (duplicate-check,
patient lookup, response-time joins across tables) and `created_at`
(dashboard date-range filters and `ORDER BY ... DESC`).

## 7. Views / Stored Procedures / Triggers

None exist. `server.js` computes all reporting (dashboard stats, wastage,
response-times) via inline SQL with subqueries/UNIONs at request time. See
`install/005_create_views.sql`, `006_create_stored_procedures.sql`,
`007_create_triggers.sql` for confirmation notes.

## 8. Known gaps to close once HCAT is reachable

- Confirm exact data types for `request_time`/`delivery_time`/`life_saving_time`
  columns — the app always sends these as `NVARCHAR` parameters, but the
  `CONVERT(..., 108)` (time format) usage in `/response-times` is consistent
  with either a live `TIME` column (implicit conversion on insert) or a plain
  `NVARCHAR` column. Inferred as `NVARCHAR(10)` here; verify and correct if
  the live column is actually `TIME`.
- Confirm `VoiceTranscriptions` has no additional columns beyond the seven
  ever inserted — this table is never read back by the app, so nothing in
  the code proves the live table doesn't have more.
- Confirm no additional tables exist beyond the five (+ `SchemaVersion`)
  listed here — this report only covers what `server.js` actually queries.
