/*
  010_seed_users_roles.sql
  Deliberately does NOT insert a default admin user here.

  node-backend/server.js's initDB() already does this idempotently on every
  backend startup — it checks `SELECT COUNT(*) FROM HospitalUsers` and, only
  if the table is empty, bcrypt-hashes "admin123" and inserts username
  "admin" / role "admin". Reimplementing that in T-SQL would require either
  hardcoding a bcrypt hash here (a second, harder-to-rotate source of truth
  for the bootstrap credential) or reinventing password hashing in SQL,
  neither of which is worth the duplication risk.

  This package intentionally delegates first-admin seeding to the existing,
  proven server.js logic — install_database.sh/.ps1 (see scripts/) create the
  schema, then the backend's own startup performs this step exactly as it
  already does today, preserving existing business behavior.

  Operational note: change the seeded admin password immediately after first
  login on any new installation — "admin123" is a bootstrap default, not a
  production credential.
*/
