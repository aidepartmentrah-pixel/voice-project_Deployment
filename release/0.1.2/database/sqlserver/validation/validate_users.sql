/*
  validate_users.sql
  Confirms HospitalUsers has at least one active admin account so nobody
  gets locked out of a fresh install (server.js's initDB() seeds this
  automatically on first backend startup — see install/010_seed_users_roles.sql
  for why this package doesn't duplicate that logic in SQL).
*/

IF NOT EXISTS (SELECT 1 FROM HospitalUsers WHERE role = 'admin' AND active = 1)
BEGIN
    PRINT 'WARNING — no active admin account found. Start node-backend once against this database to trigger its automatic admin bootstrap, then re-run this check.';
END
ELSE
BEGIN
    PRINT 'PASS — at least one active admin account exists.';
END
GO
